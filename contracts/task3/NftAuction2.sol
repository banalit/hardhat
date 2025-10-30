// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./NftAuction.sol";

contract NftAuctionV2 is NftAuction {
    // 新增功能：获取拍卖数量
    function getAuctionCount() external view returns (NftAuctionInfo) {
        return auctionInfo;
    }

    // 新增功能：测试函数
    function sayHello() external pure returns (string memory) {
        return "Hello from V2";
    }

    // 重写升级授权（保持兼容性）
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}