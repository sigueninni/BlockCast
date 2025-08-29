// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PredictionMarket.sol";
import "../src/PredictionMarketFactory.sol";
import "../src/AdminManager.sol";
import "../src/Treasury.sol";
import "../src/BetNFT.sol";
import "../src/CastToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10 ** 18); // 1M tokens
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketTest is Test {
    PredictionMarketFactory public factory;
    AdminManager public adminManager;
    Treasury public treasury;
    BetNFT public betNFT;
    MockUSDC public usdc;
    CastToken public castToken;

    address public admin = address(0x1);
    address public creator = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    function setUp() public {
        // Deploy contracts
        usdc = new MockUSDC();
        castToken = new CastToken();

        // Deploy admin manager and make admin an admin
        vm.startPrank(admin);
        adminManager = new AdminManager();
        vm.stopPrank();

        // Deploy treasury
        treasury = new Treasury(address(adminManager));

        // Deploy BetNFT
        betNFT = new BetNFT();

        // Deploy factory
        factory = new PredictionMarketFactory(
            address(adminManager),
            address(treasury),
            address(usdc),
            address(castToken),
            address(betNFT)
        );

        // Transfer BetNFT ownership to factory so it can authorize markets
        betNFT.transferOwnership(address(factory));

        // Authorize factory to mint CAST tokens
        castToken.authorizeMinter(address(factory));

        // Setup initial balances
        usdc.mint(creator, 10000 * 10 ** 18);
        usdc.mint(user1, 10000 * 10 ** 18);
        usdc.mint(user2, 10000 * 10 ** 18);
    }

    function testFullWorkflow() public {
        // 1. Creator creates a market
        vm.startPrank(creator);
        string memory question = "Will BTC reach $100k by 2025?";
        uint256 endTime = block.timestamp + 7 days;

        bytes32 marketId = factory.createMarket(question, endTime);
        address marketAddress = factory.markets(marketId);
        assertFalse(marketAddress == address(0), "Market should be created");

        PredictionMarket market = PredictionMarket(marketAddress);

        // Verify creator did NOT get CAST tokens yet (only after resolution)
        assertEq(
            castToken.balanceOf(creator),
            0,
            "Creator should not receive CAST before resolution"
        );
        vm.stopPrank();

        // 2. User1 buys YES shares
        vm.startPrank(user1);
        uint256 yesShares = 1000 * 10 ** 18;
        uint256 yesCost = market.getPriceYes(yesShares);

        usdc.approve(address(market), yesCost);
        market.buyYes(yesShares);

        assertEq(
            market.yesBalance(user1),
            yesShares,
            "User1 should have YES shares"
        );
        assertEq(
            usdc.balanceOf(user1),
            10000 * 10 ** 18 - yesCost,
            "User1 USDC should decrease"
        );

        // Check that NFT was minted
        assertEq(betNFT.balanceOf(user1), 1, "User1 should have 1 NFT");
        uint256 tokenId1 = betNFT.tokenOfOwnerByIndex(user1, 0);
        (address nftMarket, uint256 nftShares, bool isYes, ) = betNFT
            .betMetadata(tokenId1);
        assertEq(nftMarket, address(market), "NFT should reference the market");
        assertEq(nftShares, yesShares, "NFT should have correct shares");
        assertTrue(isYes, "NFT should be YES position");
        vm.stopPrank();

        // 3. User2 buys NO shares
        vm.startPrank(user2);
        uint256 noShares = 500 * 10 ** 18;
        uint256 noCost = market.getPriceNo(noShares);

        usdc.approve(address(market), noCost);
        market.buyNo(noShares);

        assertEq(
            market.noBalance(user2),
            noShares,
            "User2 should have NO shares"
        );
        assertEq(
            usdc.balanceOf(user2),
            10000 * 10 ** 18 - noCost,
            "User2 USDC should decrease"
        );

        // Check that NFT was minted
        assertEq(betNFT.balanceOf(user2), 1, "User2 should have 1 NFT");
        uint256 tokenId2 = betNFT.tokenOfOwnerByIndex(user2, 0);
        (address nftMarket2, uint256 nftShares2, bool isYes2, ) = betNFT
            .betMetadata(tokenId2);
        assertEq(
            nftMarket2,
            address(market),
            "NFT should reference the market"
        );
        assertEq(nftShares2, noShares, "NFT should have correct shares");
        assertFalse(isYes2, "NFT should be NO position");
        vm.stopPrank();

        // 4. Fast forward to after market end
        vm.warp(endTime + 1);

        // 5. Admin resolves market (YES wins)
        vm.startPrank(admin);
        uint256 reserveBeforeResolve = market.reserve();
        uint256 treasuryBalanceBefore = treasury.getBalance(address(usdc));
        uint256 creatorCastBalanceBefore = castToken.balanceOf(creator);

        market.resolveMarket(PredictionMarket.Outcome.Yes);

        // Check that fees were sent to treasury (2% of reserve)
        uint256 expectedFees = (reserveBeforeResolve * 200) / 10000; // 2%
        uint256 treasuryBalanceAfter = treasury.getBalance(address(usdc));
        assertEq(
            treasuryBalanceAfter - treasuryBalanceBefore,
            expectedFees,
            "Treasury should receive 2% fees"
        );

        // Check that creator received CAST tokens after resolution
        uint256 creatorCastBalanceAfter = castToken.balanceOf(creator);
        assertEq(
            creatorCastBalanceAfter - creatorCastBalanceBefore,
            100 * 10 ** 18,
            "Creator should receive 100 CAST after resolution"
        );
        vm.stopPrank();

        // 6. Winners redeem their rewards
        vm.startPrank(user1);
        uint256 user1BalanceBefore = usdc.balanceOf(user1);
        market.redeem();
        uint256 user1BalanceAfter = usdc.balanceOf(user1);

        assertTrue(
            user1BalanceAfter > user1BalanceBefore,
            "User1 should receive winnings"
        );
        assertEq(
            market.yesBalance(user1),
            0,
            "User1 YES balance should be 0 after redeem"
        );
        vm.stopPrank();

        // 7. Losers try to redeem (should get nothing)
        vm.startPrank(user2);
        // User2 should get "Nothing to redeem" error because they bet NO and YES won
        vm.expectRevert("Nothing to redeem");
        market.redeem();
        vm.stopPrank();

        // 8. Admin can withdraw fees from treasury
        vm.startPrank(admin);
        uint256 adminBalanceBefore = usdc.balanceOf(admin);
        treasury.withdrawToken(address(usdc), expectedFees, admin);
        uint256 adminBalanceAfter = usdc.balanceOf(admin);

        assertEq(
            adminBalanceAfter - adminBalanceBefore,
            expectedFees,
            "Admin should receive withdrawn fees"
        );
        assertEq(
            treasury.getBalance(address(usdc)),
            0,
            "Treasury should be empty after withdrawal"
        );
        vm.stopPrank();
    }

    function testPricing() public {
        console2.log("=== DEBUT TEST PRICING ===");
        
        // Create a market first
        vm.startPrank(creator);
        bytes32 marketId = factory.createMarket(
            "Test Market",
            block.timestamp + 7 days
        );
        address marketAddress = factory.markets(marketId);
        PredictionMarket market = PredictionMarket(marketAddress);
        vm.stopPrank();

        console2.log("Market cree:", marketAddress);

        // Test initial pricing (should be 1:1 when reserve is 0)
        uint256 shares = 100 * 10 ** 18;
        uint256 initialPrice = market.getPriceYes(shares);
        console2.log("=== PRICING INITIAL (reserve = 0) ===");
        console2.log("Shares demandees:", shares / 10**18, "SHARES");
        console2.log("Prix initial:", initialPrice / 10**18, "USDC");
        console2.log("Prix par share (x1000):", (initialPrice * 1000) / shares, "/1000");
        
        assertEq(initialPrice, 100 * 10 ** 18, "Initial price should be 1:1");

        // Add some liquidity first
        console2.log("\n=== PREMIER ACHAT (user1) ===");
        vm.startPrank(user1);
        uint256 firstBuy = 1000 * 10 ** 18;
        uint256 firstCost = market.getPriceYes(firstBuy);
        console2.log("User1 achete:", firstBuy / 10**18, "SHARES YES");
        console2.log("Prix total:", firstCost / 10**18, "USDC");
        console2.log("Prix moyen (x1000):", (firstCost * 1000) / firstBuy, "/1000 USDC/share");
        
        usdc.approve(address(market), firstCost);
        market.buyYes(firstBuy);
        
        // Afficher l'état après achat
        uint256 yesReserve = market.yesShares();
        uint256 noReserve = market.noShares();
        uint256 totalReserve = market.reserve();
        console2.log("Apres achat - YES reserve:", yesReserve / 10**18, "SHARES");
        console2.log("Apres achat - NO reserve:", noReserve / 10**18, "SHARES");
        console2.log("Apres achat - Total reserve:", totalReserve / 10**18, "USDC");
        vm.stopPrank();

        // Test pricing evolution with different amounts
        console2.log("\n=== EVOLUTION PRICING ===");
        
        // Test avec différents montants
        uint256 amount1 = 10 * 10**18;    // 10 shares
        uint256 price1Yes = market.getPriceYes(amount1);
        uint256 price1No = market.getPriceNo(amount1);
        console2.log("--- 10 shares ---");
        console2.log("Prix YES total:", price1Yes / 10**18);
        console2.log("Prix YES moyen (x1000):", (price1Yes * 1000) / amount1);
        console2.log("Prix NO total:", price1No / 10**18);
        console2.log("Prix NO moyen (x1000):", (price1No * 1000) / amount1);
        console2.log("Somme moyens:", ((price1Yes + price1No) * 1000) / amount1);
        
        uint256 amount2 = 100 * 10**18;   // 100 shares
        uint256 price2Yes = market.getPriceYes(amount2);
        uint256 price2No = market.getPriceNo(amount2);
        console2.log("--- 100 shares ---");
        console2.log("Prix YES total:", price2Yes / 10**18);
        console2.log("Prix YES moyen (x1000):", (price2Yes * 1000) / amount2);
        console2.log("Prix NO total:", price2No / 10**18);
        console2.log("Prix NO moyen (x1000):", (price2No * 1000) / amount2);
        console2.log("Somme moyens:", ((price2Yes + price2No) * 1000) / amount2);
        
        uint256 amount3 = 1000 * 10**18;  // 1000 shares
        uint256 price3Yes = market.getPriceYes(amount3);
        uint256 price3No = market.getPriceNo(amount3);
        console2.log("--- 1000 shares ---");
        console2.log("Prix YES total:", price3Yes / 10**18);
        console2.log("Prix YES moyen (x1000):", (price3Yes * 1000) / amount3);
        console2.log("Prix NO total:", price3No / 10**18);
        console2.log("Prix NO moyen (x1000):", (price3No * 1000) / amount3);
        console2.log("Somme moyens:", ((price3Yes + price3No) * 1000) / amount3);

        // Test that price increases as more shares are bought
        uint256 smallAmount = 100 * 10 ** 18;
        uint256 largeAmount = 1000 * 10 ** 18;

        uint256 priceSmall = market.getPriceYes(smallAmount);
        uint256 priceLarge = market.getPriceYes(largeAmount);
        
        console2.log("\n=== COMPARAISON FINAL ===");
        console2.log("Prix petit achat (100 shares):", priceSmall / 10**18);
        console2.log("Prix gros achat (1000 shares):", priceLarge / 10**18);
        console2.log("Prix moyen petit (x1000):", (priceSmall * 1000) / smallAmount);
        console2.log("Prix moyen gros (x1000):", (priceLarge * 1000) / largeAmount);

        assertTrue(
            priceLarge > priceSmall,
            "Price should increase for larger amounts"
        );
        
        console2.log("=== FIN TEST PRICING ===\n");
    }

    function testAccessControl() public {
        // Create a market first
        vm.startPrank(creator);
        bytes32 marketId = factory.createMarket(
            "Test Market",
            block.timestamp + 7 days
        );
        address marketAddress = factory.markets(marketId);
        PredictionMarket market = PredictionMarket(marketAddress);
        vm.stopPrank();

        // Test that non-admin cannot resolve market
        vm.warp(block.timestamp + 8 days);
        vm.startPrank(user1);
        vm.expectRevert("Not admin");
        market.resolveMarket(PredictionMarket.Outcome.Yes);
        vm.stopPrank();

        // Test that admin can resolve market
        vm.startPrank(admin);
        market.resolveMarket(PredictionMarket.Outcome.Yes);
        vm.stopPrank();

        // Test that non-admin cannot withdraw from treasury
        vm.startPrank(user1);
        vm.expectRevert("Not admin");
        treasury.withdrawToken(address(usdc), 100, user1);
        vm.stopPrank();
    }

    function testMarketStates() public {
        vm.startPrank(creator);
        bytes32 marketId = factory.createMarket(
            "Test Market",
            block.timestamp + 7 days
        );
        address marketAddress = factory.markets(marketId);
        PredictionMarket market = PredictionMarket(marketAddress);
        vm.stopPrank();

        // Test that users can't redeem before resolution
        vm.startPrank(user1);
        vm.expectRevert("Not resolved");
        market.redeem();
        vm.stopPrank();

        // Test that admin can't resolve before end time
        vm.startPrank(admin);
        vm.expectRevert("Too early");
        market.resolveMarket(PredictionMarket.Outcome.Yes);
        vm.stopPrank();
    }

    function testFactoryControls() public {
        // Test factory pause
        vm.startPrank(admin);
        factory.pauseFactory(true);
        vm.stopPrank();

        // Test that creation fails when paused
        vm.startPrank(creator);
        vm.expectRevert("Market creation paused");
        factory.createMarket("Test Market", block.timestamp + 7 days);
        vm.stopPrank();

        // Test unpause
        vm.startPrank(admin);
        factory.pauseFactory(false);
        vm.stopPrank();

        // Test that creation works again
        vm.startPrank(creator);
        factory.createMarket("Test Market", block.timestamp + 7 days);
        vm.stopPrank();
    }

    function testConditionalCastReward() public {
        // Test that creators only get CAST after resolution, not at creation
        vm.startPrank(creator);
        uint256 initialCastBalance = castToken.balanceOf(creator);

        bytes32 marketId = factory.createMarket(
            "Test Market",
            block.timestamp + 7 days
        );
        address marketAddress = factory.markets(marketId);
        PredictionMarket market = PredictionMarket(marketAddress);

        // Creator should not have received CAST yet
        assertEq(
            castToken.balanceOf(creator),
            initialCastBalance,
            "Creator should not receive CAST at creation"
        );
        vm.stopPrank();

        // Add some trading activity
        vm.startPrank(user1);
        uint256 shares = 100 * 10 ** 18;
        uint256 cost = market.getPriceYes(shares);
        usdc.approve(address(market), cost);
        market.buyYes(shares);
        vm.stopPrank();

        // Fast forward and resolve
        vm.warp(block.timestamp + 8 days);
        vm.startPrank(admin);
        market.resolveMarket(PredictionMarket.Outcome.Yes);
        vm.stopPrank();

        // Now creator should have received CAST
        assertEq(
            castToken.balanceOf(creator),
            initialCastBalance + 100 * 10 ** 18,
            "Creator should receive CAST after resolution"
        );
    }

    function testNFTSecondaryMarket() public {
        // Create a market and buy some shares
        vm.startPrank(creator);
        bytes32 marketId = factory.createMarket(
            "Test Market",
            block.timestamp + 7 days
        );
        address marketAddress = factory.markets(marketId);
        PredictionMarket market = PredictionMarket(marketAddress);
        vm.stopPrank();

        // User1 buys YES shares and gets NFT
        vm.startPrank(user1);
        uint256 shares = 1000 * 10 ** 18;
        uint256 cost = market.getPriceYes(shares);
        usdc.approve(address(market), cost);
        market.buyYes(shares);

        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        vm.stopPrank();

        // User1 lists NFT for sale
        vm.startPrank(user1);
        uint256 listingPrice = 1.5 ether; // 1.5 ETH
        betNFT.listNFT(tokenId, listingPrice);

        (
            uint256 listedTokenId,
            uint256 price,
            address seller,
            bool active
        ) = betNFT.listings(tokenId);
        assertEq(listedTokenId, tokenId, "Listed token ID should match");
        assertEq(price, listingPrice, "Listed price should match");
        assertEq(seller, user1, "Seller should be user1");
        assertTrue(active, "Listing should be active");
        vm.stopPrank();

        // User2 buys the NFT
        vm.deal(user2, 2 ether); // Give user2 some ETH
        vm.startPrank(user2);
        uint256 user1BalanceBefore = user1.balance;

        betNFT.buyNFT{value: listingPrice}(tokenId);

        // Check ownership transfer
        assertEq(
            betNFT.ownerOf(tokenId),
            user2,
            "User2 should now own the NFT"
        );
        assertEq(betNFT.balanceOf(user1), 0, "User1 should have 0 NFTs");
        assertEq(betNFT.balanceOf(user2), 1, "User2 should have 1 NFT");

        // Check payment
        assertEq(
            user1.balance,
            user1BalanceBefore + listingPrice,
            "User1 should receive payment"
        );

        // Check that shares were transferred in the market
        assertEq(
            market.yesBalance(user1),
            0,
            "User1 should have 0 YES shares after selling NFT"
        );
        assertEq(
            market.yesBalance(user2),
            shares,
            "User2 should have the YES shares after buying NFT"
        );

        // Check listing is inactive
        (, , , bool activeAfter) = betNFT.listings(tokenId);
        assertFalse(activeAfter, "Listing should be inactive after sale");
        vm.stopPrank();

        // Now test that the NEW owner (user2) gets the rewards, not the original buyer (user1)
        // Fast forward and resolve market as YES
        vm.warp(block.timestamp + 8 days);
        vm.startPrank(admin);
        market.resolveMarket(PredictionMarket.Outcome.Yes);
        vm.stopPrank();

        // User2 (new owner) should be able to redeem
        vm.startPrank(user2);
        uint256 user2UsdcBefore = usdc.balanceOf(user2);
        market.redeem();
        uint256 user2UsdcAfter = usdc.balanceOf(user2);
        assertTrue(
            user2UsdcAfter > user2UsdcBefore,
            "User2 should receive winnings as new NFT owner"
        );
        vm.stopPrank();

        // User1 (original buyer) should NOT be able to redeem
        vm.startPrank(user1);
        vm.expectRevert("Nothing to redeem");
        market.redeem();
        vm.stopPrank();
    }

    function testNFTListingRestrictions() public {
        // Create a market and buy shares
        vm.startPrank(creator);
        bytes32 marketId = factory.createMarket(
            "Test Market",
            block.timestamp + 1 hours
        );
        address marketAddress = factory.markets(marketId);
        PredictionMarket market = PredictionMarket(marketAddress);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 shares = 100 * 10 ** 18;
        uint256 cost = market.getPriceYes(shares);
        usdc.approve(address(market), cost);
        market.buyYes(shares);

        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);

        // Should be able to list before market ends
        betNFT.listNFT(tokenId, 1 ether);
        vm.stopPrank();

        // Fast forward past market end
        vm.warp(block.timestamp + 2 hours);

        // Should not be able to buy after market ends
        vm.deal(user2, 2 ether);
        vm.startPrank(user2);
        vm.expectRevert("Market ended");
        betNFT.buyNFT{value: 1 ether}(tokenId);
        vm.stopPrank();
    }
}
