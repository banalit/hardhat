// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftAuction.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "hardhat/console.sol";

//导入"UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract NftAuctionFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable, IERC721Receiver {

    receive() external payable {}
    fallback() external payable {}

    function deposit() external payable {
        // 充值逻辑（如记录余额）
    }


    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    address private admin;

    NftAuction public implementation;

    address[] public allAuctions;
    
    mapping(address nftContract=> mapping(uint256 tokenId =>address auctionAddr)) public getAuction;

    event AuctionCreated(address auctionAddress, address nftContract, uint256 indexed tokenId, address indexed seller, uint256 startPrice, uint256 duration);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override virtual onlyAdmin {
        // 只有管理员可以授权升级
        // implementation = new NftAuction2(address(this), admin);
    }

    // 修复：实现合约仅作为模板，不初始化；工厂自身初始化Ownable
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __OwnableUpgradeable_init(); // 初始化工厂的Ownable，owner为部署者
        admin = msg.sender;
        implementation = new NftAuction(); // 仅创建实现合约实例，不调用其initialize
    }

    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _duration
    ) external returns(address) {
        address _seller = msg.sender;
        require(_nftContract != address(0), "Invalid NFT contract address");
        require(getAuction[_nftContract][_tokenId] == address(0), "Auction already exists for this NFT");
        require(_startPrice > 0, "Start price must be greater than zero");
        require(_duration > 3, "Duration must be greater than 3s");

        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId)==_seller, "Seller is not the owner of the NFT");
        require(nft.getApproved(_tokenId)==address(this)||
                nft.isApprovedForAll(_seller, address(this)),
                "No permission to transfer NFT");

        bytes32 salt = keccak256(abi.encodePacked(_nftContract, _tokenId, block.timestamp));
        address payable auction = payable(Clones.cloneDeterministic(address(implementation), salt));
        // 初始化 clone 的状态
        NftAuction(auction).initialize(address(this), admin);
        NftAuction(auction).createAuction(
                    _nftContract,
                    _tokenId,
                    _seller,
                    _startPrice,
                    _duration);
        allAuctions.push(auction);
        getAuction[_nftContract][_tokenId] = auction;

        // Transfer the NFT to the auction contract
        console.log("auction", auction);
        console.log("nft", _nftContract);
        console.log("tokenId", _tokenId);
        console.log("seller", _seller);
        // nft.approve(auction, _tokenId);
        // nft.safeTransferFrom(_seller, auction, _tokenId);
        nft.safeTransferFrom(_seller, address(auction), _tokenId);

        emit AuctionCreated(auction, _nftContract, _tokenId, _seller, _startPrice, _duration);
        return auction;
    }

    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }

    function getAdmin() external view returns (address) {
        return admin;
    }

    function onERC721Received(address operator, address from, uint256 tokenId,bytes calldata data) external pure returns (bytes4) {
        console.log("onERC721Received called");
        //把方法入参全部打印出来
        console.log("operator: {}", operator);
        console.log("from: {}", from);
        console.log("tokenId: {}", tokenId);
        console.log("data length: {}", data.length);

        return IERC721Receiver.onERC721Received.selector;
    }
}