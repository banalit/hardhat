const {ethers, upgrades} = require("hardhat");


module.exports = async function(hre) {

  const TOKEN_ID = 1;
  const STARTING_PRICE = ethers.parseEther("1.0");
  const DURATION = 10; // 10 seconds
  
  async function deployMockNft() {
    const MockERC721 = await ethers.getContractFactory("MyNft");
    const mockNft = await MockERC721.deploy();
    await mockNft.waitForDeployment();
    return mockNft;
  }
  
   async function deployFeed() {
      // 部署 Mock 价格预言机（模拟 ETH/USD 价格：2000 美元，8 位小数）
      const MockAggregator = await ethers.getContractFactory("MockAggregatorV3");
      mockPriceFeed = await MockAggregator.deploy(
          ethers.parseUnits("2000", 8), // 价格：2000 * 10^8（符合 Chainlink 小数位）
          8 // 小数位：8
      );
      await mockPriceFeed.waitForDeployment();
   }

  [owner, seller, bidder1, bidder2] = await ethers.getSigners();
  // 部署NFT模拟合约
  nftMock = await deployMockNft();
  await deployFeed();
  // nftMock = await NFTMock.deploy();
  // await nftMock.deployed();//v6 remove this method
  await nftMock.mint(seller.address, TOKEN_ID); // 给卖家 mint 一个NFT

  // 部署工厂合约
  const AuctionFactory = await ethers.getContractFactory("NftAuctionFactory");
  console.log("Deploying AuctionFactory...");

    //部署NftAuction
  const NftAuctionImpl = await ethers.getContractFactory("NftAuction");
  const nftAuctionImpl = await NftAuctionImpl.deploy();
  const factory = await upgrades.deployProxy(AuctionFactory, [nftAuctionImpl.target], { initializer: "initialize" });
  await factory.waitForDeployment();
  console.log("AuctionFactory deployed to:", factory.address);

  // 验证合约（可选）
  // 定义需要验证的公网（如 sepolia、mainnet，本地网络跳过）
  const validNetworks = ["sepolia", "mainnet", "goerli"];
  if (validNetworks.includes(hre.network.name)) {
    console.log("Waiting for block confirmations...");
    try{
      await factory.deployTransaction.wait(5); // 等待5个区块确认
      await hre.run("verify:verify", {
        address: await upgrades.erc1967.getImplementationAddress(factory.address),
        constructorArguments: [],
      });
      console.log("All contracts verified successfully!");
    } catch (error) {
      // 容错处理：避免验证失败导致脚本中断
      if (error.message.includes("Already Verified")) {
        console.log("Contracts are already verified!");
      } else {
        console.error("Contract verification failed:", error.message);
      }
    }
  }
}

module.exports.tags = ["NftAuctionFactory", "MockPriceFeed"];

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });