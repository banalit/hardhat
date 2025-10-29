const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "YOUR_DEPLOYED_FACTORY_ADDRESS"; // 替换为实际部署的代理地址
  const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactoryV2");
  console.log("Upgrading AuctionFactory to V2...");
  const factoryV2 = await upgrades.upgradeProxy(proxyAddress, AuctionFactoryV2);
  await factoryV2.deployed();
  console.log("AuctionFactory upgraded to V2 at:", factoryV2.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });