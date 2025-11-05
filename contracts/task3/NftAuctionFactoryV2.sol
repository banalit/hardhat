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
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
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

    function upgradeAuctionImplementation() external onlyOwner {
        NftAuctionV2 newImplementation = new NftAuctionV2();
        implementation = newImplementation;
    }

    function getAuctionCount() external view returns (uint256) {
        return allAuctions.length;
    }
}