const {ethers, upgrades} = require("hardhat");

async function main() {
  // 部署工厂合约
  const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
  console.log("Deploying AuctionFactory...");
  const factory = await upgrades.deployProxy(AuctionFactory, [], { initializer: "initialize" });
  await factory.deployed();
  console.log("AuctionFactory deployed to:", factory.address);

  // 验证合约（可选）
  if (process.env.HARDHAT_NETWORK !== "hardhat") {
    console.log("Waiting for block confirmations...");
    await factory.deployTransaction.wait(5); // 等待5个区块确认
    await hre.run("verify:verify", {
      address: await upgrades.erc1967.getImplementationAddress(factory.address),
      constructorArguments: [],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });