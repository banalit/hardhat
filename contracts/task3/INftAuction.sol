// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INftAuction {
    struct NftAuctionInfo {
        address nftContract;
        uint256 tokenId; //NFT tokenId
        address seller;
        uint256 startPrice; //default usdc
        uint256 highestBid;
        address highestBidder;
        address bidToken; // Address of the ERC20 token used for bidding. address(0) represent ETH.
        uint256 startTime;
        uint256 duration;
        bool ended;
    }

    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        address _seller,
        uint256 _startPrice,
        uint256 _duration
    ) external;

    function getAuctionInfo() external view returns (NftAuctionInfo memory);

    function bid(address _bidToken, uint256 _amount) external payable ;
    
    function endAuction() external;

    function setPriceFeed(address tokenAddress, address priceFeed, uint8 decimals) external;
    function claimRefund() external;
}