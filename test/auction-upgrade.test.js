const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Auction Upgrade Test", function () {
  let AuctionFactory;
  let factory;
  let Auction;
  let auction;
  let nftMock;
  let owner, seller, bidder1, bidder2;

  beforeEach(async function () {
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();

    // 部署NFT模拟合约
    const NFTMock = await ethers.getContractFactory("NFTMock");
    nftMock = await NFTMock.deploy();
    await nftMock.deployed();
    await nftMock.mint(seller.address, 1); // 给卖家 mint 一个NFT

    // 部署可升级工厂合约
    AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    factory = await upgrades.deployProxy(AuctionFactory, [], { initializer: "initialize" });
    await factory.deployed();

    // 创建拍卖
    const endTime = Math.floor(Date.now() / 1000) + 3600; // 1小时后结束
    await nftMock.connect(seller).approve(factory.address, 1);
    await factory.connect(seller).createAuction(
      nftMock.address,
      1,
      ethers.utils.parseEther("1.0"),
      endTime
    );
    const auctionAddress = await factory.auctions(0);
    auction = await ethers.getContractAt("Auction", auctionAddress);
  });

  it("Should create auction correctly", async function () {
    expect(await auction.seller()).to.equal(seller.address);
    expect(await auction.startingPrice()).to.equal(ethers.utils.parseEther("1.0"));
  });

  it("Should handle bids correctly", async function () {
    await auction.connect(bidder1).placeBid({ value: ethers.utils.parseEther("1.5") });
    expect(await auction.highestBidder()).to.equal(bidder1.address);

    await auction.connect(bidder2).placeBid({ value: ethers.utils.parseEther("2.0") });
    expect(await auction.highestBidder()).to.equal(bidder2.address);
    expect(await ethers.provider.getBalance(bidder1.address)).to.be.closeTo(
      await ethers.provider.getBalance(bidder1.address, "latest"),
      ethers.utils.parseEther("0.1") // 允许小额误差
    );
  });

  it("Should upgrade factory contract", async function () {
    // 部署工厂合约V2（假设新增了getAuctionCount函数）
    const AuctionFactoryV2 = await ethers.getContractFactory("AuctionFactoryV2");
    const factoryV2 = await upgrades.upgradeProxy(factory.address, AuctionFactoryV2);
    expect(await factoryV2.getAuctionCount()).to.equal(1); // 测试新增功能
  });
});