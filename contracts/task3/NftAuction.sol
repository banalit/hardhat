// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./INftAuction.sol";
//导入ReentrancyGuard
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";

contract NftAuction is INftAuction, ReentrancyGuard, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address private admin;
    address private factory;
    NftAuctionInfo public auctionInfo;

    mapping(address tokenAddress => AggregatorV3Interface feed) private priceFeeds;
    mapping(address tokenAddress => uint8 decimals) private priceFeedDecimals;
    mapping(address refunder => uint256 refundAmount) public refundable;

    event BidPlaced(address indexed bidder, address nftContract, uint256 tokenId, uint256 amount, address tokenAddress);
    event AuctionEnded(address indexed winner, address nftContract, uint256 tokenId, uint256 amount, address tokenAddress);
    event Refunded(address refunder, uint256 amount);

    modifier onlyAdminOrSeller() {
        require(msg.sender == admin ||
                msg.sender == auctionInfo.seller, 
                "Only admin or seller can call this function");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner(), "Only admin can call this function");
        _;
    }

    modifier onlyFactory(){
        require(msg.sender == factory,
                "Only factory can call this function");
        _;

    }

    /// @custom:oz-upgrades-unsafe-allow-constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) override virtual internal onlyOwner {}

    // 在合约内部添加（靠近 constructor 附近）
    function initialize(address _factory, address _admin) external initializer {
        // __Initializable_init();
        __UUPSUpgradeable_init();
        __Ownable_init(_admin); // 初始化Ownable，已设置owner为_admin，无需再transferOwnership
        // transferOwnership(_admin);
        // 防止重复初始化
        require(factory == address(0), "Already initialized");
        require(_factory != address(0) && _admin != address(0), "Invalid addresses");

        factory = _factory;
        admin = _admin;

        // 初始化默认 price feed（与 constructor 中一致）
        priceFeeds[address(0)] = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        priceFeedDecimals[address(0)] = 8;
    }
    

    function setPriceFeed(address tokenAddress, address priceFeed, uint8 decimals) public onlyAdmin override {
        // require(tokenAddress != address(0), "Invalid token address");
        require(priceFeed != address(0), "Invalid price feed address");
        require(decimals > 0, "Invalid decimals (must > 0)"); // 强制验证小数位
        priceFeeds[tokenAddress] = AggregatorV3Interface(priceFeed);
        priceFeedDecimals[tokenAddress] = decimals;
    }

    function getValidatedPrice(address tokenAddress) public view returns(uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[tokenAddress];
        require(address(priceFeed)!=address(0), "price feed not found");
        (
            uint80 roundId,
            int256 answer,
            , //startedAt
            uint256 updatedAt,
            uint80 answerInRound
        ) = priceFeed.latestRoundData();
        require(answerInRound> roundId, "invalid round");
        // console.log("answer: %s", answer);
        require(answer>0, "invalid answer(non-positive)");
        require(updatedAt +3600 >=block.timestamp, "price feed outdated");
        return uint256(answer);
    }
    
    function calculateValue(address tokenAddress, uint256 amount) public view returns (uint256) {
        uint256 price = getValidatedPrice(tokenAddress);
        uint8 decimals = priceFeedDecimals[tokenAddress];
        require(decimals>0, "token decimal not set");

        return (amount * price)/10**uint256(decimals);
    }
    
    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        address _seller,
        uint256 _startPrice,
        uint256 _duration
    ) external onlyFactory override {
        require(_seller != address(0), "Invalid seller address");
        require(admin != address(0), "Invalid admin address");

        auctionInfo = NftAuctionInfo({
            nftContract: _nftContract,
            tokenId: _tokenId,
            seller: _seller,
            startPrice: _startPrice,
            highestBid: 0,
            highestBidder: address(0),
            bidToken: address(0),
            startTime: block.timestamp,
            duration: _duration,
            ended: false
        });
    }

    function getAuctionInfo() external view override returns (NftAuctionInfo memory) {
        return auctionInfo;
    }

    function bid(address _bidToken, uint256 _amount) external override payable {
        NftAuctionInfo storage info = auctionInfo;
        require(!info.ended, "Auction already ended");
        //当前时间timestamp小于auction的结束时间：startTime + duration
        require(block.timestamp < (info.startTime + info.duration), "Auction has expired");
        
        if (_bidToken==address(0)) {
            //eth
            _amount = msg.value;
            require(_amount>0, "eth amount must >0");
        } else {
            //ERC20
            require(_amount>0, "amount must >0");
            IERC20 erc20 = IERC20(_bidToken);
            require(erc20.allowance(msg.sender, address(this))>=_amount, "erc20 allowance insufficient");
            erc20.transferFrom(msg.sender, address(this), _amount);
        }
        uint256 bidValue = calculateValue(_bidToken, _amount);
        require(bidValue>=info.startPrice, "should >= startPrice");
        uint256 highValue = calculateValue(info.bidToken, info.highestBid);
        require(bidValue>highValue, "should > highestValue");
        
        if (info.highestBidder != address(0)) {
            _refundPreviousBid(info.highestBidder, info.highestBid);
        }
        //更新最高出价
        info.highestBidder = msg.sender;
        info.bidToken = _bidToken;
        info.highestBid = _amount;

        emit BidPlaced(msg.sender, info.nftContract, info.tokenId, _amount, _bidToken);
    }


    function endAuction() external override onlyAdminOrSeller {
        NftAuctionInfo storage info = auctionInfo;
        require(!info.ended, "fail, it's already ended");
        require(block.timestamp>=(info.startTime+info.duration), "time still not end");

        // 新增：验证当前合约是否持有该 NFT
        require(IERC721(info.nftContract).ownerOf(info.tokenId) == address(this), "Contract does not own NFT");
        
        info.ended = true;
        if (info.highestBidder != address(0)) {
            //有出价，划账
            IERC721(info.nftContract).safeTransferFrom(address(this), info.highestBidder, info.tokenId);
            _transferFundsToSeller();
        } else {
            //nft返回给卖家
            IERC721(info.nftContract).safeTransferFrom(address(this), info.seller, info.tokenId);
        }
        emit AuctionEnded(info.highestBidder, info.nftContract, info.tokenId, info.highestBid, info.bidToken);

    }

    //退款给竞拍者
    function _refundPreviousBid(address _bidder, uint256 _amount) internal {
        if (auctionInfo.bidToken == address(0)) {
            //eth
            // payable(_bidder).transfer(_amount);
            refundable[_bidder] += _amount;
        } else {
            IERC20(auctionInfo.bidToken).transfer(_bidder, _amount);
        }
    }

    //转移资金给卖家
    function _transferFundsToSeller() internal {
        address payable seller = payable(auctionInfo.seller);
        if (auctionInfo.bidToken == address(0)) {
            //eth
            seller.transfer(auctionInfo.highestBid);
            (bool success, ) = seller.call{value: auctionInfo.highestBid}("");
            require(success, "ETH transfer failed");
        } else {
            bool success = IERC20(auctionInfo.bidToken).transfer(seller, auctionInfo.highestBid);
            require(success, "ERC20 transfer failed");
        }
    }

    function claimRefund() external nonReentrant override {
        address refunder = msg.sender;
        uint256 amount = refundable[refunder];
        require(amount > 0, "No refund available");
        refundable[refunder] = 0; // 先清零
        (bool success, ) = payable(refunder).call{value: amount}(""); // 再转账
        require(success, "Refund failed");
        emit Refunded(refunder, amount);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    
}