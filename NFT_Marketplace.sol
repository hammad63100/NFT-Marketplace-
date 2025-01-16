// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICreateCollection {
    struct NFT {
        string name;
        uint256 tokenId;
        address owner;
        bool exists;
        uint256 price; 
    }

    function getNFTDetails(uint256 nftId) external view returns (string memory, address, bool, uint256); // Include price in the return values
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
    mapping(uint256 => uint256) private  salePrice;
    mapping(address => uint256[]) private  userSellList;

    event AuctionCreated(uint256 indexed nftId, uint256 startingPrice, uint256 startTime, uint256 endTime, address seller);
    event BidPlaced(uint256 indexed nftId, address bidder, uint256 bidAmount);
    event AuctionFinalized(uint256 indexed nftId, address winner, uint256 winningBid);
    event NFTListed(uint256 indexed collectionId, uint256 indexed nftId, uint256 price);
    event NFTSold(uint256 indexed nftId, address seller, address buyer, uint256 price);
    event NFTSaleCancelled(uint256 indexed nftId, address seller);
    event AuctionCancelled(uint256 indexed nftId, address seller);

    constructor(address _createCollectionAddress) {
        createCollectionContract = ICreateCollection(_createCollectionAddress);
    }

    function createAuction(uint256 nftId, uint256 startingPrice, uint256 startTime, uint256 endTime) external {
        require(startingPrice >= 30000000000000000, "Starting price must be at least 0.03 ETH");  // 0.03 ETH in wei
        (, address nftOwner, bool nftExists, uint256 mintPrice) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(nftOwner == msg.sender, "You are not the owner of this NFT");
        require(!listedForSale[nftId], "NFT is already listed for sale");
        require(endTime - startTime >= 1 minutes, "Auction must run for at least 1 minute");
        require(startTime >= block.timestamp, "Start time must be current or future");
        require(endTime > startTime, "End time must be after start time");
        require(!nftInAuction[nftId], "Auction already exists for this NFT");
        require(startingPrice >= mintPrice, "Starting price must be at least the mint price");

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

        (, address nftOwner, bool nftExists, uint256 mintPrice) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(nftOwner == msg.sender, "You are not the owner of this NFT");
        require(price >= mintPrice, "Sale price must be at least the mint price");

        listedForSale[nftId] = true;
        salePrice[nftId] = price;
        userSellList[msg.sender].push(nftId); // Add NFT to seller's list

        emit NFTListed(0, nftId, price);  // Using 0 as collection ID since we're not tracking it anymore
    }

    function cancelSell(uint256 nftId) external {
        require(listedForSale[nftId], "NFT is not listed for sale");

        (, address nftOwner, bool nftExists, ) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(nftOwner == msg.sender, "You are not the owner of this NFT");

        listedForSale[nftId] = false;
        salePrice[nftId] = 0;

        // Remove NFT from seller's list
        uint256[] storage sellList = userSellList[msg.sender];
        for (uint256 i = 0; i < sellList.length; i++) {
            if (sellList[i] == nftId) {
                sellList[i] = sellList[sellList.length - 1];
                sellList.pop();
                break;
            }
        }

        emit NFTSaleCancelled(nftId, msg.sender);
    }

    function placeBid(uint256 nftId) external payable {
        Auction storage auction = auctions[nftId];
        require(auction.isActive, "Auction is not active"); // New check added
        require(block.timestamp >= auction.startTime, "Auction has not started yet");
        require(block.timestamp <= auction.endTime, "Auction has already ended");
        require(msg.value > auction.highestBid, string(abi.encodePacked("Bid amount must be higher than the current highest bid: ", toString(auction.highestBid))));
        require(msg.value > auction.startingPrice, "Bid amount must be higher than the starting price");

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
        require(block.timestamp > auction.endTime, "Auction has not ended yet"); // Ensure auction has ended

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

    function cancelAuction(uint256 nftId) external {
        Auction storage auction = auctions[nftId];
        require(auction.isActive, "Auction is not active");
        require(auction.seller == msg.sender, "You are not the seller of this auction");

        auction.isActive = false;
        nftInAuction[nftId] = false;

        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        emit AuctionCancelled(nftId, msg.sender);
    }

    function buyNFT(uint256 nftId) external payable {
        require(listedForSale[nftId], "NFT not listed for sale");
        uint256 price = salePrice[nftId];
        require(msg.value == price, "Incorrect payment amount");

        (, address seller, bool nftExists, ) = createCollectionContract.getNFTDetails(nftId);
        require(nftExists, "NFT does not exist");
        require(msg.sender != seller, "Cannot buy your own NFT");

        listedForSale[nftId] = false;
        salePrice[nftId] = 0;

        // Remove NFT from seller's list
        uint256[] storage sellList = userSellList[seller];
        for (uint256 i = 0; i < sellList.length; i++) {
            if (sellList[i] == nftId) {
                sellList[i] = sellList[sellList.length - 1];
                sellList.pop();
                break;
            }
        }

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
