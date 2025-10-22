// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// 引入CCIP核心接口
import "@chainlink/contracts-ccip/src/v0.8/ccip/token/ERC721/CCIPERC721.sol"; // 跨链NFT标准
import "@chainlink/contracts-ccip/src/v0.8/ccip/Client.sol";

contract MyNft is ERC721Enumerable, Ownable, CCIPERC721 {
    // 新增：CCIP Router地址（不同链地址不同，如Sepolia: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59）
    address public ccipRouter;

    string private _tokenURI;
    receive() external payable {}
    fallback() external payable {}

    constructor() 
        ERC721("Troll", "Troll") 
        Ownable(msg.sender)
        CCIPErc721(_ccipRouter, "CCIP-Troll", "CCIP-Troll") // CCIP初始化（Router+跨链Token名）
    {
        require(_ccipRouter!=address(0), "ccipRouter invalid");
        ccipRouter = _ccipRouter;
    }

    function crossChainTransfer(
        uint64 destinationChainSelector, // 目标链选择器（如Ethereum Sepolia: 16015286601757825753）
        address receiver, // 目标链接收地址
        uint256 tokenId // 跨链NFT的TokenId
    ) external payable
    {
        require(ownerOf(tokenId)==msg.sender, "Only NFT owner can cross-chain transfer");
        // 调用CCIPERC721的send函数（需支付CCIP燃气费，用msg.value覆盖）
        _send(
            destinationChainSelector,
            receiver,
            tokenId,
            msg.sender, // 费用支付者
            msg.sender, // 退款接收者（若燃气费剩余）
            bytes("") // 额外数据（可选）
        );
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