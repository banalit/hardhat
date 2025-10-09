const {ethers, deployments, upgrades} = require("hardhat")
const fs = require("fs")
const path = require("path")

module.exports = async ({getNamedAccounts, deployments})=>{
    const {save} = deployments
    const {deployer} = await getNamedAccounts()
    console.log("部署合约地址", deployer);

    const storePath = path.resolve(__dirname, "./.cache/proxyNftAuction.json");
    const storeData = fs.readFileSync(storePath, "utf-8");
    const {proxyAddr, implAddress, abi} = JSON.parse(storeData);

    const NftAuctionV2 = await ethers.getContractFactory("NftAuctionV2");
    const nftAuctionProxyV2 = await upgrades.upgradeProxy(proxyAddr, NftAuctionV2, {call:"admin"});
    await nftAuctionProxyV2.waitForDeployment();
    const proxyAddress2 = await nftAuctionProxyV2.getAddress();
    const implAddress2 = upgrades.erc1967.getImplementationAddress(proxyAddress2);


    await save("NftAuctionProxy2", {
        abi, 
        address: proxyAddress2,
        implAddress2
    })


}


module.exports.tags = ["upgradeNftAuction"]