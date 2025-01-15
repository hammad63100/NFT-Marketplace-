// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICreateCollection {
    struct NFT {
        string name;
        uint256 tokenId;
        address owner;
        bool exists;
    }

    function getNFTDetails(uint256 nftId) external view returns (string memory, address, bool);
    function transferNFT(uint256 nftId, address to) external;
    function getUserCollectionsByAddress(address user) external view returns (uint256[] memory);
}

contract NFTMarketplace {
    struct Auction {
        uint256 nftId;
        uint256 startingPrice;
        uint256 startTime;
        uint256 endTime;
        address payable seller;
        address highestBidder;
        uint256 highestBid;
        bool isActive;
    }

    ICreateCollection public createCollectionContract;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => bool) public nftInAuction;
    mapping(uint256 => bool) public listedForSale;
    mapping(uint256 => uint256) public salePrice;

    event AuctionCreated(uint256 indexed nftId, uint256 startingPrice, uint256 startTime, uint256 endTime, address seller);
    event BidPlaced(uint256 indexed nftId, address bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed nftId, address winner, uint256 winningBid);
    event NFTListed(uint256 indexed collectionId, uint256 indexed nftId, uint256 price);
    event NFTSold(uint256 indexed nftId, address seller, address buyer, uint256 price);

    constructor(address _createCollectionAddress) {
        createCollectionContract = ICreateCollection(_createCollectionAddress);
    }

    function createAuction(uint256 nftId, uint256 startingPrice, uint256 startTime, uint256 endTime) external {
        (, address nftOwner, bool nftExists) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(nftOwner == msg.sender, "You are not the owner of this NFT");
        require(!listedForSale[nftId], "NFT is already listed for sale");
        require(endTime - startTime >= 1 minutes, "Auction must run for at least 1 minute");
        require(startTime >= block.timestamp, "Start time must be current or future");
        require(endTime > startTime, "End time must be after start time");
        require(!nftInAuction[nftId], "Auction already exists for this NFT");

        auctions[nftId] = Auction({
            nftId: nftId,
            startingPrice: startingPrice,
            startTime: startTime,
            endTime: endTime,
            seller: payable(msg.sender),
            highestBidder: address(0),
            highestBid: 0,
            isActive: true
        });
        nftInAuction[nftId] = true;

        emit AuctionCreated(nftId, startingPrice, startTime, endTime, msg.sender);
    }

    function sellNFT(uint256 nftId, uint256 price) external {
        require(price >= 30000000000000000, "Price must be at least 0.03 ETH");  // 0.03 ETH in wei
        require(!listedForSale[nftId], "NFT already listed");
        require(!nftInAuction[nftId], "NFT is currently in auction");

        (, address nftOwner, bool nftExists) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(nftOwner == msg.sender, "You are not the owner of this NFT");

        listedForSale[nftId] = true;
        salePrice[nftId] = price;

        emit NFTListed(0, nftId, price);  // Using 0 as collection ID since we're not tracking it anymore
    }

    function placeBid(uint256 nftId) external payable {
        Auction storage auction = auctions[nftId];
        require(block.timestamp >= auction.startTime, "Auction has not started yet");
        require(block.timestamp <= auction.endTime, "Auction has already ended");
        require(msg.value > auction.highestBid, string(abi.encodePacked("Bid amount must be higher than the current highest bid: ", toString(auction.highestBid))));

        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit BidPlaced(nftId, msg.sender, msg.value);
    }

    function finalizeAuction(uint256 nftId) public {
        Auction storage auction = auctions[nftId];
        require(auction.isActive, "Auction is not active");
        
        // Get NFT owner through the interface
        (, address nftOwner, ) = createCollectionContract.getNFTDetails(nftId);
        require(nftOwner == msg.sender, "You are not the owner of this NFT");

        auction.isActive = false;
        nftInAuction[nftId] = false;

        if (auction.highestBidder != address(0)) {
            createCollectionContract.transferNFT(nftId, auction.highestBidder);
            auction.seller.transfer(auction.highestBid);

            emit AuctionFinalized(nftId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionFinalized(nftId, address(0), 0);
        }
    }

    function buyNFT(uint256 nftId) external payable {
        require(listedForSale[nftId], "NFT not listed for sale");
        uint256 price = salePrice[nftId];
        require(msg.value == price, "Incorrect payment amount");

        (, address seller, bool nftExists) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(msg.sender != seller, "Cannot buy your own NFT");

        listedForSale[nftId] = false;
        salePrice[nftId] = 0;

        payable(seller).transfer(msg.value);
        createCollectionContract.transferNFT(nftId, msg.sender);

        emit NFTSold(nftId, seller, msg.sender, price);
    }

    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }

    // Add helper function for converting uint to string
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}




