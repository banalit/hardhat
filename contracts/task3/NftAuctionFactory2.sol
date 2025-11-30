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

    event ImplementationUpdated(string message, address newImpl);

    function upgradeExistingAuctions() internal onlyAdmin {
        address newImpl = address(implementation);
        require(newImpl != address(0), "Invalid implementation address");
        for (uint256 i = 0; i < allAuctions.length; i++) {
            // 调用 OpenZeppelin 5.x 的 upgradeToAndCall，传入空 data 实现纯升级
            NftAuction(allAuctions[i]).upgradeToAndCall(newImpl, "");
        }
        emit ImplementationUpdated("Auction implementation updated to V2 successfully!", address(implementation));
    }

    function getAuctionCount() external view returns (uint256) {
        return allAuctions.length;
    }
}