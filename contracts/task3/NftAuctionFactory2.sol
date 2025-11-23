// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "./NftAuctionFactory.sol";
import "./NftAuctionV2.sol";

contract NftAuctionFactory2 is NftAuctionFactory {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function sayHello() external pure returns (string memory) {
        return "Hello from Factory V2";
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // 只有管理员可以授权升级
    }

    function upgradeAuctionImplementation(address _newImpl) external onlyOwner {
        require(_newImpl != address(0), "Invalid implementation");
        implementation = NftAuctionV2(_newImpl); // 仅存储地址，不部署
    }

    function getAuctionCount() external view returns (uint256) {
        return allAuctions.length;
    }
}