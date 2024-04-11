// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Import ERC721 interface to interact with NFTs
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol"; // Import ERC721Holder to safely receive NFTs
import "@openzeppelin/contracts/access/Ownable.sol"; // Import Ownable for ownership control

contract NFTMarketplace is ERC721Holder, Ownable {
    uint256 public feePercentage;   // Fee percentage charged by the marketplace owner
    uint256 private constant PERCENTAGE_BASE = 100;

    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 startPrice;
        uint256 duration;
        uint256 startTime;
        address highestBidder;
        uint256 highestBid;
        bool isActive;
    }

    mapping(address => mapping(uint256 => Listing)) private listings;
    mapping(address => mapping(uint256 => Auction)) private auctions;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTAuctionStarted(address indexed seller, uint256 indexed tokenId, uint256 startPrice, uint256 duration);
    event NFTAuctionEnded(address indexed seller, address indexed winner, uint256 indexed tokenId, uint256 price);

    // Constructor to set the default fee percentage
    constructor() {
        feePercentage = 2;  // Setting the default fee percentage to 2%
    }

    // Function to list an NFT for sale
    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create a new listing
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    // Function to start an auction for an NFT
    function startAuction(address nftContract, uint256 tokenId, uint256 startPrice, uint256 duration) external {
        require(startPrice > 0, "Starting price must be greater than zero");
        require(duration > 0, "Auction duration must be greater than zero");

        // Transfer the NFT from the seller to the marketplace contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Create a new auction
        auctions[nftContract][tokenId] = Auction({
            seller: msg.sender,
            tokenId: tokenId,
            startPrice: startPrice,
            duration: duration,
            startTime: block.timestamp,
            highestBidder: address(0),
            highestBid: 0,
            isActive: true
        });

        emit NFTAuctionStarted(msg.sender, tokenId, startPrice, duration);
    }

    // Function to place a bid on an ongoing auction
    function placeBid(address nftContract, uint256 tokenId) external payable {
        Auction storage auction = auctions[nftContract][tokenId];
        require(auction.isActive, "Auction is not active");
        require(block.timestamp < auction.startTime + auction.duration, "Auction has ended");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");

        if (auction.highestBidder != address(0)) {
            // Refund the previous highest bidder
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
    }

    // Function to end an active auction and transfer the NFT to the highest bidder
    function endAuction(address nftContract, uint256 tokenId) external {
        Auction storage auction = auctions[nftContract][tokenId];
        require(auction.isActive, "Auction is not active");
        require(block.timestamp >= auction.startTime + auction.duration, "Auction has not ended yet");

        // Transfer the NFT to the highest bidder
        IERC721(nftContract).safeTransferFrom(address(this), auction.highestBidder, tokenId);

        // Transfer the payment to the seller after deducting the fee
        uint256 feeAmount = (auction.highestBid * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = auction.highestBid - feeAmount;
        payable(auction.seller).transfer(sellerAmount); // Transfer payment to the seller

        auction.isActive = false;

        emit NFTAuctionEnded(auction.seller, auction.highestBidder, tokenId, auction.highestBid);
    }

    // Other existing functions remain the same...

    // Function to set the fee percentage by the marketplace owner
    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage < PERCENTAGE_BASE, "Fee percentage must be less than 100");

        feePercentage = newFeePercentage;
    }
}