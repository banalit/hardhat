const { ethers, upgrades } = require("hardhat");

async function upgradeOld() {
  const proxyAddress = "YOUR_DEPLOYED_FACTORY_ADDRESS"; // 替换为实际部署的代理地址
  const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactoryV2");
  console.log("Upgrading AuctionFactory to V2...");
  const factoryV2 = await upgrades.upgradeProxy(proxyAddress, AuctionFactoryV2);
  await factoryV2.deployed();
  console.log("AuctionFactory upgraded to V2 at:", factoryV2.address);
}

async function upgradeUUPS() {
  // 1. 部署新的拍卖实现
  const NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
  const auctionV2Impl = await NftAuctionV2.deploy();
  // 部署工厂合约 V2
  const NftAuctionFactoryV2 = await ethers.getContractFactory("NftAuctionFactoryV2");
  const factoryV2 = await upgrades.upgradeProxy(existingFactoryAddress, NftAuctionFactoryV2);
  // 2. 工厂更新拍卖实现地址（新创建的拍卖将使用 V2）
  await factoryV2.upgradeAuctionImplementation();

  // 3. 对现有拍卖合约执行升级
  factoryV2.getAllAuctions().forEach(async (auctionAddress) => {
    const existingAuction = await ethers.getContractAt("NftAuction", auctionAddress);
    await existingAuction.upgradeTo(auctionV2Impl.address);
  });

}

upgradeUUPS()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });