// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

// 引入ERC165接口（判断合约是否支持特定接口）
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// 定义CCIP-ERC721的核心接口（仅包含跨链相关函数）
interface ICCIPERC721 is IERC721 {
    // 跨链转移函数（CCIP-ERC721的核心特征）
    function send(
        uint64 destinationChainSelector,
        address receiver,
        uint256 tokenId,
        address feeToken,
        address refundAddress,
        bytes calldata extraArgs
    ) external payable;

    // 接收跨链NFT的钩子函数
    function _ccipReceive(
        Client.Any2EVMMessage calldata message,
        uint256 tokenId,
        address receiver
    ) external;
}

// 计算CCIP-ERC721的interfaceId（用于判断合约类型）
bytes4 constant CCIP_ERC721_INTERFACE_ID = type(ICCEP721).interfaceId;