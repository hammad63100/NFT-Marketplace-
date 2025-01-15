// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CreateCollection {
    uint256 private _tokenIds;

    struct Collection {
        uint256 collectionId;
        string name;
        address owner;
        bool isActive;
    }

    struct NFT {
        string name;
        uint256 tokenId;
        address owner;
        bool exists;
    }

    mapping(uint256 => Collection) private collections;
    mapping(address => uint256[]) private userCollections;
    mapping(uint256 => NFT) private nfts;
    mapping(uint256 => uint256[]) private collectionNFTs;

    event CollectionCreated(uint256 indexed collectionId, string name, address owner);
    event NFTMinted(address indexed owner, uint256 indexed tokenId);

    function _generateRandomId() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender)));
    }

    function createCollection(string memory _name) external returns (uint256) {
        require(bytes(_name).length > 0, "Collection name cannot be empty");

        uint256 collectionId = _generateRandomId();
        require(collections[collectionId].owner == address(0), "Collection ID collision");

        Collection memory newCollection = Collection({
            collectionId: collectionId,
            name: _name,
            owner: msg.sender,
            isActive: true
        });

        collections[collectionId] = newCollection;
        userCollections[msg.sender].push(collectionId);

        emit CollectionCreated(collectionId, _name, msg.sender);

        return collectionId;
    }

    function mintNFT(uint256 _collectionId, string memory _name) external {
        require(bytes(_name).length > 0, "NFT name cannot be empty");
        require(collections[_collectionId].owner == msg.sender, "You don't own this collection");
        require(collections[_collectionId].isActive, "Collection is not active");

        uint256 tokenId = _generateRandomId();
        require(!nfts[tokenId].exists, "NFT ID collision");

        nfts[tokenId] = NFT({
            name: _name,
            tokenId: tokenId,
            owner: msg.sender,
            exists: true
        });

        collectionNFTs[_collectionId].push(tokenId);

        emit NFTMinted(msg.sender, tokenId);
    }

    function getNFTsByCollection(uint256 _collectionId) external view returns (uint256[] memory) {
        require(_collectionId > 0, "Invalid collection ID");
        return collectionNFTs[_collectionId];
    }

    function getCollectionDetailsById(uint256 _collectionId) external view returns (Collection memory) {
        require(_collectionId > 0, "Invalid collection ID");
        return collections[_collectionId];
    }

    function getUserCollectionsByAddress(address _user) external view returns (uint256[] memory) {
        return userCollections[_user];
    }

    function getNFTDetails(uint256 tokenId) external view returns (string memory, address, bool) {
        require(nfts[tokenId].exists, "NFT does not exist");
        NFT memory nft = nfts[tokenId];
        return (nft.name, nft.owner, nft.exists);
    }

    function transferNFT(uint256 tokenId, address to) external {
        require(nfts[tokenId].exists, "NFT does not exist");
       

        nfts[tokenId].owner = to;
    }
}
