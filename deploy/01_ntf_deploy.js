const { deployments, upgrades, ethers } = require("hardhat")
const fs = require("fs");
const path = require("path");

// deploy/00_deploy_my_contract.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;
    const { deployer, user1 } = await getNamedAccounts();
    console.log(`account deployer:${deployer}, user1:${user1}`);
    const NftAuction = await ethers.getContractFactory("NftAuction");
    const nftAuctionProxy = await upgrades.deployProxy(NftAuction, [
        // "0x0000000000000000000000000000000",
        // 100 * 1000,
        // ehters.parseEther("0.000000000000000001"),
        // ethers.ZeroAddress,
        // 1
    ], {
        initializer: "initialize"
    })
    //等待10s钟，让区块链网络有时间处理部署事务
    
    


    // new Promise(resolve => setTimeout(resolve, 10000));

    await nftAuctionProxy.waitForDeployment();
    const proxyAddr = await nftAuctionProxy.getAddress();
    console.log("代理合约地址:", proxyAddr);
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddr);
    console.log("实现合约地址:", implAddress);

    const storePath = path.resolve(__dirname, "./.cache/proxyNftAuction.json");
    fs.writeFileSync(storePath, 
        JSON.stringify({ 
            proxyAddr, 
            implAddress, 
            abi: NftAuction.interface.format("json") }));

    await save("NftAuctionProxy", {
        abi: NftAuction.interface.format("json"),
        address: proxyAddr,
        implAddress: implAddress
    });
    // await deploy('MyContract', {
    //   from: deployer,
    //   args: ['Hello'],
    //   log: true,
    // });
  };
module.exports.tags = ['deployNftAuction'];