const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Auction Upgrade Test", function () {
  let AuctionFactory;
  let factory;
  let NftAuction;
  let auction;
  let nftMock;
  let owner, seller, bidder1, bidder2;
  let mockPriceFeed;
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

  beforeEach(async function () {
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();

    // 部署NFT模拟合约
    nftMock = await deployMockNft();
    await deployFeed();
    // nftMock = await NFTMock.deploy();
    // await nftMock.deployed();//v6 remove this method
    await nftMock.mint(seller.address, TOKEN_ID); // 给卖家 mint 一个NFT
    expect(await nftMock.ownerOf(TOKEN_ID)).to.equal(seller.address, "Seller should own the NFT");
    expect(await nftMock.ownerOf(TOKEN_ID)).to.not.equal(bidder1.address, "Bidder1 should not own the NFT");

    //部署NftAuction
    const NftAuctionImpl = await ethers.getContractFactory("NftAuction");
    const nftAuctionImpl = await NftAuctionImpl.deploy();
    // 部署可升级工厂合约
    AuctionFactory = await ethers.getContractFactory("NftAuctionFactory");
    factory = await upgrades.deployProxy(AuctionFactory, [nftAuctionImpl.target], { initializer: "initialize" });
    await factory.waitForDeployment(); // 等待部署完成，避免地址未就绪
    expect(await factory.getAdmin()).to.equal(owner.address, "Owner should be admin");

    // 创建拍卖
    const approveTx = await nftMock.connect(seller).approve(factory.target, TOKEN_ID);
    // await approveTx.waitForDeployment(); // 等待授权交易完成
    expect(await nftMock.getApproved(TOKEN_ID)).to.equal(factory.target, "Factory should have NFT approval");
    const createAuctionTx = await factory.connect(seller).createAuction(
      nftMock.target,
      TOKEN_ID,
      STARTING_PRICE,
      DURATION
    );
    // await createAuctionTx.waitForDeployment(); // 等待创建拍卖交易完成

    const auctionAddress = await factory.allAuctions(0);
    expect(auctionAddress).to.not.be.undefined;
    expect(auctionAddress).to.not.equal(ethers.ZeroAddress, "Auction address should not be zero address");
    auction = await ethers.getContractAt("NftAuction", auctionAddress);
    // 配置拍卖合约使用 Mock 预言机（ETH 对应 address(0)）
    await auction.setPriceFeed(ethers.ZeroAddress, mockPriceFeed.target, 8);
  });

    // 测试1：验证拍卖创建正确（修复：通过 getAuctionInfo() 获取结构体）
    it("Should create auction correctly", async function () {
    const auctionInfo = await auction.getAuctionInfo(); // 修复：用结构体获取信息
    expect(auctionInfo.seller).to.equal(seller.address, "Seller should match");
    expect(auctionInfo.startPrice).to.equal(STARTING_PRICE, "Starting price should match");
    expect(auctionInfo.nftContract).to.equal(nftMock.target, "NFT contract should match");
  });

  // 测试2：验证出价逻辑正确（修复：用 bid() 方法，传递 ETH 对应地址 0）
  it("Should handle bids correctly", async function () {
    const bid1Amount = ethers.parseEther("1.5");
    const bid2Amount = ethers.parseEther("2.0");

    // 竞拍者1出价（修复：调用 bid() 而非 placeBid()，传递 address(0) 表示 ETH）
    await auction.connect(bidder1).bid(
      ethers.ZeroAddress, // 修复：v6 用 ZeroAddress 替代 address(0)
      bid1Amount,
      { value: bid1Amount }
    );
    let auctionInfo = await auction.getAuctionInfo();
    expect(auctionInfo.highestBidder).to.equal(bidder1.address, "Bidder1 should be highest bidder");

    // 竞拍者2出价更高（修复：同上述 bid() 方法）
    await auction.connect(bidder2).bid(
      ethers.ZeroAddress,
      bid2Amount,
      { value: bid2Amount }
    );
    auctionInfo = await auction.getAuctionInfo();
    expect(auctionInfo.highestBidder).to.equal(bidder2.address, "Bidder2 should be highest bidder");

    // 验证竞拍者1的退款（ETH 出价被超越后，退款计入 refundable 映射）
    const bid1Refund = await auction.refundable(bidder1.address);
    expect(bid1Refund).to.equal(bid1Amount, "Bidder1 should have refundable amount");
  });

  it("Should upgrade factory contract", async function () {
    // 部署工厂合约V2（假设新增了getAuctionCount函数）
    const NftAuctionFactoryV2 = await ethers.getContractFactory("NftAuctionFactory2");
    const factoryV2 = await upgrades.upgradeProxy(factory.target, NftAuctionFactoryV2);
    // await factoryV2.waitForDeployment();
    expect(await factoryV2.getAuctionCount()).to.equal(1, "Auction count should be 1"); // 测试新增功能
  });
  
});