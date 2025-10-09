require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy"); // 确保添加此行
require("@openzeppelin/hardhat-upgrades")
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  namedAccounts:{
    deployer: 0,
    user1: 1,
    user2: 2
  }
};
