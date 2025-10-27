// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// 引入CCIP核心接口
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import "@chainlink/contracts-ccip/contracts/Router.sol";
import "./ICCIPERC721.sol";
// import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";


contract MyNft is ERC721Enumerable, Ownable, ICCIPERC721, CCIPReceiver {
    // 新增：CCIP Router地址（不同链地址不同，如Sepolia: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59）
    address public ccipRouter;
    address public factoryAddress;
    uint64 public chainSelector; // Ethereum Sepolia chain selector 16015286601757825753
    string public constant CREATE_AUCTION_SIGNATURE = "createCrossChainAuction(uint64,address,address,uint256,address,uint256,uint256)";
    bytes4 public constant CREATE_AUCTION_ACTION = bytes4(keccak256(bytes(CREATE_AUCTION_SIGNATURE)));

    mapping(uint256 tokenId => bool isCrossChaining) public crossChainInProgress;

    event NFTCrossChainInitiated(
        uint256 indexed tokenId,
        address sender,
        uint64 destinationChainSelector,
        address receiver,
        bytes32 messageId
    );

    event NFTCrossChainReceived(
        uint256 indexed tokenId,
        address sender,
        uint64 sourceChainSelector,
        address receiver,
        bytes32 messageId
    );

    string private _tokenURI;
    receive() external payable {}
    fallback() external payable {}

    constructor(address _ccipRouter, uint64 _chainSelector, address _factoryAddress) 
        ERC721("Troll", "Troll") 
        Ownable(msg.sender)
    {
        require(_ccipRouter!=address(0), "ccipRouter invalid");
        ccipRouter = _ccipRouter;
        chainSelector = _chainSelector;
        factoryAddress = _factoryAddress;
    }

    function crossChainTransfer(
        uint64 destinationChainSelector, // 目标链选择器（如Ethereum Sepolia: 16015286601757825753）
        address destinationNftContract,  //目标链路的nft合约地址
        address receiver, // 目标链接收地址
        uint256 tokenId  // 跨链NFT的TokenId
        ,uint256 startPrice,
        ,uint256 duration
    ) external payable returns (bytes32 messageId)
    {
        require(ownerOf(tokenId)==msg.sender, "Only NFT owner can cross-chain transfer");
        require(!crossChainInProgress[tokenId], "Cross-chain in progress");
        
        // 1. 标记NFT为跨链中（防止重复操作）
        crossChainInProgress[tokenId] = true;
        
        // 2. 销毁原链NFT
        _burn(tokenId);

        // 3. 构造CCIP消息：包含NFT信息（tokenId、原所有者、目标接收者等）
        bytes4 action = CREATE_AUCTION_ACTION;
        ICCIPRouter ccipRouter = ICCIPRouter(ccipRouter);
        bytes memory data = abi.encode(
                tokenId, 
                msg.sender, // 原所有者
                receiver,   // 目标接收者
                chainSelector // 原链选择器
                ,startPrice
                ,duration
        );
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(destinationNftContract), // 目标链NFT合约
            data: abi.encode(action, data),
            tokenAmounts: new Client.EVMTokenAmount[](0), // 不携带额外代币
            extraArgs: bytes(""),
            // extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300000})), // 目标链执行gas
            feeToken: address(0) // 用ETH支付CCIP费用
        });
        //预估gas费用
        uint256 estimatedFee = ccipRouter.ccipEstimateFee(destinationChainSelector, message);
        require(msg.value >= estimatedFee, "Insufficient fee for CCIP" + string(estimatedFee));
        // 4. 发送CCIP消息
        messageId = ccipRouter.ccipSend{value: msg.value}(destinationChainSelector, message);

        emit NFTCrossChainInitiated(tokenId, msg.sender, destinationChainSelector, receiver, messageId);
        return messageId;
    }
    
    // 辅助函数：设置CCIP路由器（可选）
    function setCcipRouter(address _router) external onlyOwner {
        ccipRouter = ICCIPRouter(_router);
    }

    // 重写CCIP接收NFT的钩子（可选，用于接收跨链NFT时触发自定义逻辑）
    function _ccipReceive(
        Client.Any2EVMMessage calldata message,
        uint256 tokenId,
        address receiver
    ) internal override {
        // 示例：接收跨链NFT后，自动创建拍卖（需关联工厂合约）
        // NftAuctionFactory(factoryAddress).createCrossChainAuction(msg.sender, tokenId, ...);
        super._ccipReceive(message, tokenId, receiver);
        emit NFTCrossChainReceived(tokenId, message.sender, message.sourceChainSelector, receiver, message.messageId);
    }


    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    function tokenURI(uint256 ) public view override returns (string memory) {
        return _tokenURI;
    }

    function setTokenURI(string memory newTokenURI) external onlyOwner {
        _tokenURI = newTokenURI;
    }
    function deposit() external payable {
        // 充值逻辑（如记录余额）
    }

}