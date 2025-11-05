require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy"); // 确保添加此行
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      // 配置 OpenZeppelin 所需的版本（0.8.22 和 0.8.21）
      { version: "0.8.22" },
      { version: "0.8.21" },
      { version: "0.8.20" },
      // 可选：添加你自己合约的主要版本（如 0.8.19）
      { version: "0.8.19" }
    ],
    // version: "0.8.20", // 明确指定版本
    settings: {
      optimizer: {
        enabled: true, // 启用优化器，降低部署 gas 成本
        runs: 200 // 优化运行次数，适合生产环境
      }
    }
  },
  namedAccounts:{
    deployer: 0, // 第一个测试账户作为部署者
    user1: 1,    // 第二个账户作为用户1
    user2: 2     // 第三个账户作为用户2
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY].filter(Boolean), // 过滤空值，避免私钥未配置时报错
      saveDeployments: true // 保存部署信息到 deployments 目录（配合 hardhat-deploy）
    },
    // 新增本地测试网配置，方便本地开发
    hardhat: {
      chainId: 31337, // 标准本地链 ID
      saveDeployments: true
    }
  },
  // 合约验证配置（@nomicfoundation/hardhat-verify 要求使用 verify 字段）
  verify: {
    etherscan: {
      apiKey: process.env.ETHERSCAN_API_KEY // Etherscan 验证 API Key
    }
  },
  // 配置部署脚本路径（可选，默认是 deploy 目录）
  paths: {
    deploy: "scripts/deploy" // 如果你习惯将部署脚本放在 scripts/deploy 下
  }
};