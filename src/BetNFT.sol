// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./PredictionMarket.sol";

contract BetNFT is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;

    struct BetMetadata {
        address market;
        uint256 shares;
        bool isYes; // true for YES, false for NO
        uint256 timestamp;
    }

    struct ListingOffer {
        uint256 tokenId;
        uint256 price;
        address seller;
        bool active;
    }

    mapping(uint256 => BetMetadata) public betMetadata;
    mapping(uint256 => ListingOffer) public listings;
    mapping(address => bool) public authorizedMarkets;

    uint256 private _nextTokenId = 1;

    event BetNFTMinted(
        uint256 indexed tokenId,
        address indexed market,
        address indexed owner,
        uint256 shares,
        bool isYes
    );

    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event NFTSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    event ListingCanceled(uint256 indexed tokenId);

    constructor() ERC721("BlockCast Bet NFT", "BCBET") Ownable(msg.sender) {}

    modifier onlyAuthorizedMarket() {
        require(authorizedMarkets[msg.sender], "Not authorized market");
        _;
    }

    function authorizeMarket(address market) external onlyOwner {
        authorizedMarkets[market] = true;
    }

    function revokeMarket(address market) external onlyOwner {
        authorizedMarkets[market] = false;
    }

    function mintBetNFT(
        address to,
        address market,
        uint256 shares,
        bool isYes
    ) external onlyAuthorizedMarket returns (uint256) {
        uint256 tokenId = _nextTokenId++;

        betMetadata[tokenId] = BetMetadata({
            market: market,
            shares: shares,
            isYes: isYes,
            timestamp: block.timestamp
        });

        _mint(to, tokenId);

        emit BetNFTMinted(tokenId, market, to, shares, isYes);
        return tokenId;
    }

    function listNFT(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(price > 0, "Price must be positive");
        require(!listings[tokenId].active, "Already listed");

        // Check that market is still open for trading
        BetMetadata memory metadata = betMetadata[tokenId];
        PredictionMarket market = PredictionMarket(metadata.market);
        PredictionMarket.MarketInfo memory marketInfo = market.getMarketInfo();
        require(
            marketInfo.status == PredictionMarket.MarketStatus.Open,
            "Market must be open"
        );
        require(block.timestamp < marketInfo.endTime, "Market ended");

        listings[tokenId] = ListingOffer({
            tokenId: tokenId,
            price: price,
            seller: msg.sender,
            active: true
        });

        emit NFTListed(tokenId, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external {
        require(listings[tokenId].seller == msg.sender, "Not your listing");
        require(listings[tokenId].active, "Listing not active");

        listings[tokenId].active = false;

        emit ListingCanceled(tokenId);
    }

    function buyNFT(uint256 tokenId) external payable {
        ListingOffer memory listing = listings[tokenId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");

        // Check that market is still open for trading
        BetMetadata memory metadata = betMetadata[tokenId];
        PredictionMarket market = PredictionMarket(metadata.market);
        PredictionMarket.MarketInfo memory marketInfo = market.getMarketInfo();
        require(
            marketInfo.status == PredictionMarket.MarketStatus.Open,
            "Market must be open"
        );
        require(block.timestamp < marketInfo.endTime, "Market ended");

        address seller = listing.seller;
        uint256 price = listing.price;

        // Mark listing as inactive
        listings[tokenId].active = false;

        // Transfer balances in the market from seller to buyer
        market.transferShares(
            seller,
            msg.sender,
            metadata.shares,
            metadata.isYes
        );

        // Transfer NFT
        _transfer(seller, msg.sender, tokenId);

        // Transfer payment to seller
        payable(seller).transfer(price);

        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit NFTSold(tokenId, seller, msg.sender, price);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");

        BetMetadata memory metadata = betMetadata[tokenId];

        // Simple JSON without base64 encoding to avoid stack too deep
        return
            string(
                abi.encodePacked(
                    'data:application/json,{"name":"BlockCast Bet #',
                    tokenId.toString(),
                    '","description":"Prediction market position NFT","attributes":[{"trait_type":"Market","value":"',
                    Strings.toHexString(uint160(metadata.market)),
                    '"},{"trait_type":"Shares","value":',
                    (metadata.shares / 1e18).toString(),
                    '},{"trait_type":"Position","value":"',
                    metadata.isYes ? "YES" : "NO",
                    '"},{"trait_type":"Timestamp","value":',
                    metadata.timestamp.toString(),
                    "}]}"
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
}
