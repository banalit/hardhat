// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftAuction.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract NftAuctionFactory is Initializable, UUPSUpgradeable {

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyAdmin
    {}

    address private admin;

    NftAuction public implementation;

    address[] public allAuctions;
    
    mapping(address nftContract=> mapping(uint256 tokenId =>address auctionAddr)) public getAuction;

    event AuctionCreated(address auctionAddress, address nftContract, uint256 indexed tokenId, address indexed seller, uint256 startPrice, uint256 duration);

    function initialize() public initializer {
        admin = msg.sender;
        implementation = new NftAuction(address(this), admin);
    }

    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _duration
    ) external returns(address auction) {
        address _seller = msg.sender;
        require(_nftContract != address(0), "Invalid NFT contract address");
        require(getAuction[_nftContract][_tokenId] == address(0), "Auction already exists for this NFT");
        require(_startPrice > 0, "Start price must be greater than zero");
        require(_duration > 3, "Duration must be greater than 3s");

        IERC721 nft = IERC721(_nftContract);
        require(nft.ownerOf(_tokenId)==_seller, "Seller is not the owner of the NFT");
        require(nft.getApproved(_tokenId)==address(this)||
                nft.isApprovedForAll(_seller, address(this)),
                "No permission to transfer NFT");

        bytes32 salt = keccak256(abi.encodePacked(_nftContract, _tokenId, block.timestamp));
        auction = Clones.cloneDeterministic(address(implementation), salt);(implementation);
        NftAuction(auction).createAuction(
                    _nftContract,
                    _tokenId,
                    _seller,
                    _startPrice,
                    _duration);
        allAuctions.push(auction);
        getAuction[_nftContract][_tokenId] = auction;

        // Transfer the NFT to the auction contract
        nft.approve(auction, _tokenId);
        nft.safeTransferFrom(_seller, auction, _tokenId);

        emit AuctionCreated(auction, _nftContract, _tokenId, _seller, _startPrice, _duration);
    }

    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }

    function getAdmin() external view returns (address) {
        return admin;
    }

}