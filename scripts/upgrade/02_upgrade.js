const { ethers, upgrades } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function upgradeOld() {
  const proxyAddress = "YOUR_DEPLOYED_FACTORY_ADDRESS"; // 替换为实际部署的代理地址
  const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactoryV2");
  console.log("Upgrading AuctionFactory to V2...");
  const factoryV2 = await upgrades.upgradeProxy(proxyAddress, AuctionFactoryV2);
  await factoryV2.deployed();
  console.log("AuctionFactory upgraded to V2 at:", factoryV2.address);
}

async function upgradeUUPS() {
  // 读取缓存的工厂代理地址
  const cachePath = path.resolve(__dirname, "../deploy/.cache/proxyFactory.json");
  if (!fs.existsSync(cachePath)) {
    throw new Error("Factory proxy address not found. Deploy first using deploy-upgradeable.js");
  }
  const { proxyAddr: existingFactoryProxyAddress } = JSON.parse(fs.readFileSync(cachePath, "utf-8"));

  // 1. 部署新的拍卖实现
  const NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
  const auctionV2Impl = await NftAuctionV2.deploy();
  await auctionV2Impl.waitForDeployment(); 
  const auctionV2ImplAddress = await auctionV2Impl.getAddress();

  // 部署工厂合约 V2
  const NftAuctionFactoryV2 = await ethers.getContractFactory("NftAuctionFactory2");
  const factoryV2 = await upgrades.upgradeProxy(
    existingFactoryProxyAddress,
    NftAuctionFactoryV2,
    { kind: "uups" } // 显式声明 UUPS 类型（OpenZeppelin 5.x 建议）
    );
  await factoryV2.waitForDeployment();
  const factoryV2Address = await factoryV2.getAddress();
  console.log(`✅ NftAuctionFactory upgraded to V2 at: ${factoryV2Address}`);

  // 验证工厂升级后的实现地址
  const factoryV2ImplAddress = await upgrades.erc1967.getImplementationAddress(factoryV2Address);
  console.log(`✅ Factory V2 implementation address: ${factoryV2ImplAddress}`);

  // 2. 工厂更新拍卖实现地址（新创建的拍卖将使用 V2）
  console.log("\n🚀 Updating factory's auction implementation to V2...");
  let updateTx = await factoryV2.upgradeAuctionImplementation(auctionV2ImplAddress);
  const receipt = await updateTx.wait(); // 获取交易回执
  const event = await receipt.logs.find(log => log.fragment && log.fragment.name === "ImplementationUpdated");
  if (event) {
    const [message, newImpl] = event.args;
    console.log(`\n📢 Event message: ${message}`); // 打印事件中的字符串
    console.log(`🔧 New auction implementation: ${newImpl}`);
}
let newImple = await factoryV2.implementation();
console.log(`auction imple:${newImple}`)
const helloMsg = await factoryV2.sayHello();
console.log(`🤖 Factory V2 says: ${helloMsg}`);

  // 3. 对现有拍卖合约执行升级
  // const allAuctions = await factoryV2.getAllAuctions();
  // for (const auctionAddress of allAuctions) {
  //   const existingAuction = await ethers.getContractAt("NftAuction", auctionAddress);
  //   await existingAuction.upgradeTo(auctionV2Impl.getAddress());
  // }
}

upgradeUUPS()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

  module.exports = async function(hre) {
    await upgradeUUPS();
  };
  module.exports.tags = ["upgradeV2"];