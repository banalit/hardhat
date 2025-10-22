// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftAuction.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "hardhat/console.sol";
// 引入CCIP核心接口
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/ICCIPRouter.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/ICCIPReceiver.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/CCIPReceiver.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/token/ERC721/CCIPERC721.sol"; // 跨链NFT标准
import "@chainlink/contracts-ccip/src/v0.8/ccip/token/ERC20/CCIPERC20.sol"; // 跨链ERC20标准（可选）
import "@chainlink/contracts/utils/Strings.sol";

contract NftAuctionFactory is Initializable, UUPSUpgradeable, CCIPReceiver, IERC721Receiver {

    //增加CCIP状态变量
    ICCIPRouter public ccipRouter;
    // 跨链工厂地址映射（链选择器→目标链工厂地址）
    mapping(uint64 chainSelector => address factoryOnChain) public crossChainFactories; 
    // 拍卖合约所属链选择器
    mapping(address auctionAddr => uint256 chainId) public auctionChainSelector; 
    //nft=>拍卖合约地址
    mapping(address nftContract=> mapping(uint256 tokenId =>address auctionAddr)) public getAuction;

    receive() external payable {}
    fallback() external payable {}

    function deposit() external payable {
        // 充值逻辑（如记录余额）
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyAdmin
    {}

    address private admin;

    NftAuction public implementation;

    address[] public allAuctions;
    
    event AuctionCreated(address auctionAddress, address nftContract, uint256 indexed tokenId, address indexed seller, uint256 startPrice, uint256 duration);
    // 新增：跨链拍卖创建事件
    event CrossChainAuctionCreated(
        uint64 sourceChainSelector,
        address sourceFactory,
        address auctionAddress,
        address nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 startPrice,
        uint256 duration
    );

    // 新增：CCIP消息接收 modifier（验证消息来自授权路由器）
    modifier onlyCCIPRouter() {
        require(msg.sender == address(ccipRouter), "Caller is not the CCIP Router");
        _;
    }

    function initialize(address _ccipRouter) public initializer {
        admin = msg.sender;
        require(_ccipRouter != address(0), "Invalid CCIP Router");
        ccipRouter = ICCIPRouter(_ccipRouter);
        implementation = new NftAuction(address(this), admin, _ccipRouter);
    }

    // 新增：注册跨链工厂地址（管理员操作）
    function registerCrossChainFactory(uint64 _chainSelector, address _factoryAddr) external onlyAdmin {
        require(_factoryAddr != address(0), "Invalid factory address");
        crossChainFactories[_chainSelector] = _factoryAddr;
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

        // 新增：判断NFT是否为跨链NFT（CCIP-ERC721）
        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId) == _seller, "Seller is not the owner of the NFT");
        require(
            nft.getApproved(_tokenId) == address(this) 
            || nft.isApprovedForAll(_seller, address(this)),
            "No permission to transfer NFT"
        );

        bytes32 salt = keccak256(abi.encodePacked(_nftContract, _tokenId, block.timestamp));
        address auction = Clones.cloneDeterministic(address(implementation), salt);
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
        // 记录拍卖所属链（注：block.chainid为uint256)
        auctionChainSelector[auction] = block.chainid; 


        // Transfer the NFT to the auction contract
        console.log("auction", auction);
        console.log("nft", _nftContract);
        console.log("tokenId", _tokenId);
        console.log("seller", _seller);
        // nft.approve(auction, _tokenId);
        // nft.safeTransferFrom(_seller, auction, _tokenId);
        nft.safeTransferFrom(_seller, auction, _tokenId);

        emit AuctionCreated(auction, _nftContract, _tokenId, _seller, _startPrice, _duration);
        return auction;
    }

    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }

    function getAdmin() external view returns (address) {
        return admin;
    }

    function onERC721Received(address operator, address from, uint256 tokenId,bytes calldata data) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // 新增：跨链创建拍卖（从其他链接收NFT后触发）
    function createCrossChainAuction(
        uint64 _sourceChainSelector,
        address _sourceFactory,
        address _nftContract,
        uint256 _tokenId,
        address _seller,
        uint256 _startPrice,
        uint256 _duration
    ) external onlyAdmin returns(address) {
        // 验证跨链工厂已注册
        require(crossChainFactories[_sourceChainSelector] == _sourceFactory, "Source factory not registered");
        require(getAuction[_nftContract][_tokenId] == address(0), "Auction already exists");

        // 同原创建逻辑
        bytes32 salt = keccak256(abi.encodePacked(_sourceChainSelector, _nftContract, _tokenId, block.timestamp));
        address auction = Clones.cloneDeterministic(address(implementation), salt);
        NftAuction(auction).initialize(address(this), admin, ccipRouter);
        NftAuction(auction).createAuction(_nftContract, _tokenId, _seller, _startPrice, _duration);

        // 更新状态
        allAuctions.push(auction);
        getAuction[_nftContract][_tokenId] = auction;
        auctionChainSelector[auction] = block.chainid;

        // 触发跨链拍卖事件
        emit CrossChainAuctionCreated(_sourceChainSelector, _sourceFactory, auction, _nftContract, _tokenId, _seller, _startPrice, _duration);
        return auction;
    }

    // 新增：CCIP消息接收函数（处理跨链NFT接收、跨链竞拍请求）
    function ccipReceive(Client.Any2EVMMessage calldata message) external onlyCCIPRouter override {
        // 解析消息数据（需提前约定数据格式，如：操作类型+参数）
        (bytes4 action, bytes memory data) = abi.decode(message.data, (bytes4, bytes));

        // 分支1：接收跨链NFT后创建拍卖
        if (action == bytes4(keccak256("createAuctionAfterCrossChain(uint256,address,uint256,uint256)"))) {
            (address _seller, address _nftContract, uint256 _tokenId, uint256 _startPrice, uint256 _duration) = 
                abi.decode(data, (address, address, uint256, uint256, uint256));
            // 调用跨链拍卖创建函数
            createCrossChainAuction(
                message.sourceChainSelector,
                message.sender, // 源链工厂地址
                _nftContract,
                _tokenId,
                _seller,
                _startPrice,
                _duration
            );
        }

        // 分支2：接收跨链竞拍请求（其他链用户竞拍本链拍卖）
        else if (action == bytes4(keccak256("crossChainBid(address,address,uint256)"))) {
            (address _auctionAddr, address _bidToken, uint256 _amount) = 
                abi.decode(data, (address, address, uint256));
            // 调用拍卖合约的跨链竞拍函数
            NftAuction(_auctionAddr).crossChainBid(message.sender, _bidToken, _amount);
        }
    }
}