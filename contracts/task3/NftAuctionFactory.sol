// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftAuction.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "hardhat/console.sol";

//导入"UUPSUpgradeable.sol";
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
    function initialize(address _implementation) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender); // 初始化Ownable，已设置owner为_admin，无需再transferOwnership
        admin = msg.sender;
        implementation = NftAuction(_implementation);
        // implementation = new NftAuction(); // 仅创建实现合约实例，不调用其initialize
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
        
        // 1. 验证NFT授权
        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId)==_seller, "Seller is not the owner of the NFT");
        require(nft.getApproved(_tokenId)==address(this)||
                nft.isApprovedForAll(_seller, address(this)),
                "No permission to transfer NFT");

        // 2. 生成CREATE2盐值（确保地址唯一）
        bytes32 salt = keccak256(abi.encodePacked(_nftContract, _tokenId, block.timestamp));

        // 3. 部署ERC-1967代理合约（可升级）
        bytes memory initData = abi.encodeWithSelector(
            NftAuction.initialize.selector,
            address(this), 
            admin
        );

        auctionProxy = address(new ERC1967Proxy{salt: salt}(address(implementation), initData));
        // address payable auction = payable(Clones.cloneDeterministic(address(implementation), salt));

        // 初始化 clone 的状态
        // NftAuction(auction).initialize(address(this), admin);
        NftAuction(auctionProxy).createAuction(
                    _nftContract,
                    _tokenId,
                    _seller,
                    _startPrice,
                    _duration);
        allAuctions.push(auctionProxy);
        getAuction[_nftContract][_tokenId] = auctionProxy;

        // Transfer the NFT to the auction contract
        console.log("auction", auctionProxy);
        console.log("nft", _nftContract);
        console.log("tokenId", _tokenId);
        console.log("seller", _seller);
        // nft.approve(auction, _tokenId);
        // nft.safeTransferFrom(_seller, auction, _tokenId);
        nft.safeTransferFrom(_seller, address(auctionProxy), _tokenId);

        emit AuctionCreated(auctionProxy, _nftContract, _tokenId, _seller, _startPrice, _duration);
        return auctionProxy;
    }

    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }

    function upgradeExistingAuctions() external onlyAdmin {
        for (uint256 i = 0; i < allAuctions.length; i++) {
            NftAuction(allAuctions[i]).upgradeTo(address(implementation));
        }
    }

    function getAdmin() external view returns (address) {
        return admin;
    }
    
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}