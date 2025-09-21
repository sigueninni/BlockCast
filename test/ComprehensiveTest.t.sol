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

/**
 * @title Comprehensive Test Suite for BlockCast Prediction Market
 * @dev Tests all core functionality including CPMM, pricing, trading, and NFTs
 */
contract ComprehensiveTest is Test {
    PredictionMarket public market;
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

        // Deploy BetNFT and transfer ownership to Factory so it can authorize markets
        betNFT = new BetNFT();

        // Deploy Factory
        factory = new PredictionMarketFactory(
            address(adminManager),
            address(treasury),
            address(usdc),
            address(castToken),
            address(betNFT)
        );

        // Transfer BetNFT ownership to Factory so it can authorize markets
        betNFT.transferOwnership(address(factory));

        // Give Factory permission to mint CAST tokens (as owner)
        castToken.authorizeMinter(address(factory));

        // Create market via Factory (proper way!)
        vm.startPrank(creator);
        bytes32 marketId = factory.createMarket(
            "Will Bitcoin reach $100k by end of 2025?",
            block.timestamp + 365 days
        );
        address marketAddress = factory.markets(marketId);
        market = PredictionMarket(marketAddress);
        vm.stopPrank();

        // Mint tokens to users
        usdc.mint(user1, 100000 * 1e18);
        usdc.mint(user2, 100000 * 1e18);
    }

    // === BASIC FUNCTIONALITY TESTS ===

    function testMarketCreation() public view {
        // Test market was created correctly
        (
            bytes32 id,
            string memory question,
            address marketCreator,
            uint256 endTime,

        ) = market.marketInfo();

        assertEq(question, "Will Bitcoin reach $100k by end of 2025?");
        assertEq(marketCreator, creator);
        assertTrue(endTime > block.timestamp);
        assertTrue(id != bytes32(0));
    }

    function testInitialState() public view {
        // Test initial shares state (simplified system)
        assertEq(market.yesShares(), 100e18);
        assertEq(market.noShares(), 100e18);

        // Test initial probabilities (should be 50/50)
        (uint256 probYes, uint256 probNo) = market.getProbabilities();
        assertEq(probYes, 50);
        assertEq(probNo, 50);
    }

    function testInitialPricing() public view {
        // Test balanced initial pricing - dans notre système équilibré,
        // acheter la même quantité de YES ou NO coûte le même prix au début
        uint256 price100Yes = market.getPriceYes(100 * 1e18);
        uint256 price100No = market.getPriceNo(100 * 1e18);

        // Dans un système parfaitement équilibré (100 YES, 100 NO),
        // acheter 100 shares de n'importe quel côté coûte pareil
        // Prix moyen: (50% + 66.6%) / 2 ≈ 58.3%
        assertTrue(
            price100Yes >= 55 * 1e18 && price100Yes <= 65 * 1e18,
            "YES price should be around 58%"
        );
        assertTrue(
            price100No >= 55 * 1e18 && price100No <= 65 * 1e18,
            "NO price should be around 58% (same as YES in balanced system)"
        );
        
        // Dans notre système équilibré, les prix sont symétriques
        assertEq(price100Yes, price100No, "Prices should be equal in balanced system");
    }

    // === TRADING TESTS ===

    function testBuyYesShares() public {
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);

        uint256 initialBalance = market.yesBalance(user1);
        uint256 sharesBought = 100 * 1e18;

        market.buyYes(sharesBought);

        uint256 finalBalance = market.yesBalance(user1);
        assertTrue(finalBalance > initialBalance);
        assertTrue(finalBalance == sharesBought); // User should have the shares they bought

        vm.stopPrank();
    }

    function testBuyNoShares() public {
        vm.startPrank(user2);
        usdc.approve(address(market), 1000 * 1e18);

        uint256 initialBalance = market.noBalance(user2);
        uint256 sharesBought = 100 * 1e18;

        market.buyNo(sharesBought);

        uint256 finalBalance = market.noBalance(user2);
        assertTrue(finalBalance > initialBalance);
        assertTrue(finalBalance == sharesBought); // User should have the shares they bought

        vm.stopPrank();
    }

    function testPriceProgression() public {
        // Test that prices increase with demand
        uint256 initialPriceYes = market.getPriceYes(50 * 1e18);

        // User1 buys YES shares
        vm.startPrank(user1);
        usdc.approve(address(market), 10000 * 1e18);
        market.buyYes(200 * 1e18);
        vm.stopPrank();

        uint256 newPriceYes = market.getPriceYes(50 * 1e18);

        // In our simple system, after buying YES, the price for additional YES should increase
        // because there are now more YES shares, making YES probability higher
        assertTrue(
            newPriceYes >= initialPriceYes,
            "YES price should increase after YES purchases"
        );
    }

    function testProbabilityUpdates() public {
        // Initial state
        (uint256 initialProbYes, uint256 initialProbNo) = market
            .getProbabilities();
        assertEq(initialProbYes, 50);
        assertEq(initialProbNo, 50);

        // User buys YES shares
        vm.startPrank(user1);
        usdc.approve(address(market), 5000 * 1e18);
        market.buyYes(500 * 1e18);
        vm.stopPrank();

        // Probabilities should update
        (uint256 newProbYes, uint256 newProbNo) = market.getProbabilities();
        // In our simple system, probabilities should change significantly with large purchases
        // After buying 500 YES shares, YES probability should be much higher
        assertTrue(
            newProbYes > 60,
            "YES probability should increase significantly after large YES purchase"
        );
        assertTrue(
            newProbNo < 40,
            "NO probability should decrease after YES purchase"
        );
        assertEq(
            newProbYes + newProbNo,
            100,
            "Probabilities should sum to 100"
        );
    }

    // === FEE TESTS ===

    function testProtocolFees() public {
        uint256 initialTreasuryBalance = usdc.balanceOf(address(treasury));

        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);

        // Buy shares - should generate fees
        market.buyYes(100 * 1e18);

        vm.stopPrank();

        // Fees are only transferred to treasury upon resolution
        // Advance time past market end
        vm.warp(block.timestamp + 366 days);

        // Resolve market to trigger fee transfer (nouvelle logique en 2 étapes)
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes); // Ferme le marché
        market.finalResolve(PredictionMarket.Outcome.Yes, 100); // Résolution finale avec score 100%
        vm.stopPrank();

        uint256 finalTreasuryBalance = usdc.balanceOf(address(treasury));
        assertTrue(
            finalTreasuryBalance > initialTreasuryBalance,
            "Treasury should receive protocol fees"
        );
    }

    // === RESOLUTION TESTS ===

    function testResolveMarketYes() public {
        // Setup: Users buy shares
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyNo(100 * 1e18);
        vm.stopPrank();

        // Advance time to after market end
        vm.warp(block.timestamp + 366 days);

        // Admin resolves market as YES (nouvelle logique en 2 étapes)
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes);
        market.finalResolve(PredictionMarket.Outcome.Yes, 100);
        vm.stopPrank();

        // Check resolution
        (, , , , PredictionMarket.MarketStatus status) = market.marketInfo();
        assertTrue(status == PredictionMarket.MarketStatus.Resolved);
    }

    function testRedemption() public {
        // Setup: User buys YES shares
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        vm.stopPrank();

        // Advance time to after market end
        vm.warp(block.timestamp + 366 days);

        // Resolve as YES (nouvelle logique en 2 étapes)
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes);
        market.finalResolve(PredictionMarket.Outcome.Yes, 100);
        vm.stopPrank();

        // Redeem winnings
        uint256 initialUsdcBalance = usdc.balanceOf(user1);

        vm.startPrank(user1);
        market.redeem();
        vm.stopPrank();

        uint256 finalUsdcBalance = usdc.balanceOf(user1);
        assertTrue(
            finalUsdcBalance > initialUsdcBalance,
            "User should receive winnings"
        );
        assertEq(
            market.yesBalance(user1),
            0,
            "YES balance should be zero after redemption"
        );
    }

    // === CPMM MATHEMATICAL TESTS ===

    function testPriceReflectsProbability() public {
        // Test that price equals probability in our simple system
        (uint256 initialProbYes, uint256 initialProbNo) = market
            .getProbabilities();

        // Initially should be 50/50
        assertEq(initialProbYes, 50);
        assertEq(initialProbNo, 50);

        // Execute trades to change probabilities
        vm.startPrank(user1);
        usdc.approve(address(market), 5000 * 1e18);
        market.buyYes(50 * 1e18); // Buy YES to increase YES probability
        vm.stopPrank();

        // Check that probabilities changed correctly
        (uint256 newPriceYes, ) = market.getCurrentPrice();
        (uint256 newProbYes, uint256 newProbNo) = market.getProbabilities();

        // YES probability should have increased
        assertTrue(
            newProbYes > 50,
            "YES probability should increase after YES purchase"
        );
        assertTrue(
            newProbNo < 50,
            "NO probability should decrease after YES purchase"
        );

        // Price and probability should be consistent
        uint256 expectedProbYes = (newPriceYes * 100) / 1e18;
        assertEq(
            newProbYes,
            expectedProbYes,
            "Probability should equal price percentage"
        );
    }

    // === COMPREHENSIVE WORKFLOW TEST ===

    function testFullTradingWorkflow() public {
        // 1. Initial state
        // 2. User1 buys YES shares
        vm.startPrank(user1);
        usdc.approve(address(market), 10000 * 1e18);
        market.buyYes(500 * 1e18);
        vm.stopPrank();

        // 3. User2 buys NO shares
        vm.startPrank(user2);
        usdc.approve(address(market), 10000 * 1e18);
        market.buyNo(300 * 1e18);
        vm.stopPrank();

        // 4. Check probabilities
        market.getProbabilities(); // Just call to ensure it works

        // 5. Advance time and resolve
        vm.warp(block.timestamp + 366 days);

        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes); // Ferme le marché
        market.finalResolve(PredictionMarket.Outcome.Yes, 100); // YES wins avec 100% confiance
        vm.stopPrank();

        uint256 user1BalanceBefore = usdc.balanceOf(user1);

        vm.startPrank(user1);
        market.redeem();
        vm.stopPrank();

        uint256 user1BalanceAfter = usdc.balanceOf(user1);

        assertTrue(
            user1BalanceAfter > user1BalanceBefore,
            "Winner should receive payout"
        );
    }

    // === POLYMARKET-STYLE DEMO ===
    function testPolymarketDemo() public {
        console.log("=== DEMONSTRATION SYSTEME POLYMARKET ===");

        // Etat initial
        (uint256 probYes, uint256 probNo) = market.getProbabilities();
        (uint256 priceYes, uint256 priceNo) = market.getCurrentPrice();
        console.log("INITIAL - Prob YES:", probYes);
        console.log("INITIAL - Prob NO:", probNo);
        console.log("INITIAL - Prix YES (centimes):", priceYes / 1e16);
        console.log("INITIAL - Prix NO (centimes):", priceNo / 1e16);
        console.log("Total probabilites:", probYes + probNo);

        // Achat massif de YES
        vm.startPrank(user1);
        usdc.approve(address(market), 10000 * 1e18);
        market.buyYes(500 * 1e18);
        vm.stopPrank();

        // Nouvel etat
        (probYes, probNo) = market.getProbabilities();
        (priceYes, priceNo) = market.getCurrentPrice();
        console.log("");
        console.log("APRES ACHAT 500 YES:");
        console.log("Prob YES:", probYes);
        console.log("Prob NO:", probNo);
        console.log("Prix YES (centimes):", priceYes / 1e16);
        console.log("Prix NO (centimes):", priceNo / 1e16);
        console.log("Total probabilites:", probYes + probNo);

        // Verification que tout est coherent
        assertEq(probYes + probNo, 100, "Probabilites doivent sommer a 100%");
        assertTrue(probYes > 50, "YES devrait etre > 50% apres achat massif");
    }

    // === TEST NOUVELLE LOGIQUE DE RESOLUTION ===
    
    function testTwoStageResolution() public {
        // Setup: Users trade
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        vm.stopPrank();
        
        // Marché ouvert au début
        (, , , , PredictionMarket.MarketStatus status) = market.marketInfo();
        assertTrue(status == PredictionMarket.MarketStatus.Open, "Market should be open initially");
        
        // Avancer le temps
        vm.warp(block.timestamp + 366 days);
        
        // 1ère étape: résolution préliminaire (ferme le marché)
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes);
        vm.stopPrank();
        
        // Vérifier état intermédiaire
        (, , , , status) = market.marketInfo();
        assertTrue(status == PredictionMarket.MarketStatus.PendingResolution, "Market should be pending resolution");
        assertTrue(market.isPendingResolution(), "Should be in pending state");
        assertEq(uint(market.preliminaryOutcome()), uint(PredictionMarket.Outcome.Yes), "Preliminary outcome should be Yes");
        
        // Trading devrait être bloqué maintenant
        vm.startPrank(user2);
        usdc.approve(address(market), 1000 * 1e18);
        vm.expectRevert("Market not open");
        market.buyNo(50 * 1e18);
        vm.stopPrank();
        
        // 2ème étape: résolution finale avec score de confiance
        vm.startPrank(admin);
        market.finalResolve(PredictionMarket.Outcome.Yes, 95); // 95% de confiance
        vm.stopPrank();
        
        // Vérifier résolution finale
        (, , , , status) = market.marketInfo();
        assertTrue(status == PredictionMarket.MarketStatus.Resolved, "Market should be resolved");
        assertEq(market.confidenceScore(), 95, "Confidence score should be 95");
        assertEq(uint(market.resolvedOutcome()), uint(PredictionMarket.Outcome.Yes), "Final outcome should be Yes");
        
        // Maintenant les utilisateurs peuvent récupérer leurs gains
        vm.startPrank(user1);
        market.redeem();
        vm.stopPrank();
    }

    // === NFT TESTS ===

    function testNFTMintingOnPurchase() public {
        // User1 achète des shares YES
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        
        uint256 sharesBought = 100 * 1e18;
        uint256 initialNFTBalance = betNFT.balanceOf(user1);
        
        market.buyYes(sharesBought);
        
        uint256 finalNFTBalance = betNFT.balanceOf(user1);
        
        // User devrait avoir reçu un NFT
        assertEq(finalNFTBalance, initialNFTBalance + 1, "User should receive NFT after purchase");
        
        vm.stopPrank();
    }

    function testNFTMetadata() public {
        // User1 achète des shares
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(150 * 1e18);
        vm.stopPrank();
        
        // Récupérer le token ID (devrait être 1 pour le premier mint)
        uint256 tokenId = 1;
        assertTrue(betNFT.ownerOf(tokenId) == user1, "User should own the NFT");
        
        // Vérifier les métadonnées
        (address nftMarket, uint256 nftShares, bool nftIsYes, uint256 nftTimestamp) = betNFT.betMetadata(tokenId);
        
        assertEq(nftMarket, address(market), "NFT should reference correct market");
        assertEq(nftShares, 150 * 1e18, "NFT should have correct shares amount");
        assertTrue(nftIsYes, "NFT should be marked as YES position");
    }

    function testNFTListingAndBuying() public {
        // Setup: User1 achète des shares et reçoit un NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(200 * 1e18);
        vm.stopPrank();
        
        uint256 tokenId = 1;
        uint256 listingPrice = 0.1 ether; // Prix en ETH
        
        // User1 liste son NFT
        vm.startPrank(user1);
        betNFT.listNFT(tokenId, listingPrice);
        vm.stopPrank();
        
        // Vérifier que le NFT est listé
        (uint256 listedTokenId, uint256 price, address seller, bool isListed) = betNFT.listings(tokenId);
        assertEq(price, listingPrice, "Listing price should match");
        assertEq(seller, user1, "Seller should be user1");
        assertTrue(isListed, "NFT should be listed");
        
        // User2 achète le NFT
        vm.deal(user2, 1 ether); // Donner de l'ETH à user2
        
        uint256 user1InitialEthBalance = user1.balance;
        uint256 user1InitialYesShares = market.yesBalance(user1);
        uint256 user2InitialYesShares = market.yesBalance(user2);
        
        vm.startPrank(user2);
        betNFT.buyNFT{value: listingPrice}(tokenId);
        vm.stopPrank();
        
        // Vérifications après achat
        assertEq(betNFT.ownerOf(tokenId), user2, "User2 should now own the NFT");
        assertEq(user1.balance, user1InitialEthBalance + listingPrice, "User1 should receive ETH payment");
        
        // Vérifier transfert des shares
        assertEq(market.yesBalance(user1), user1InitialYesShares - 200 * 1e18, "User1 should lose YES shares");
        assertEq(market.yesBalance(user2), user2InitialYesShares + 200 * 1e18, "User2 should gain YES shares");
        
        // Le listing devrait être supprimé
        (, , , bool stillListed) = betNFT.listings(tokenId);
        assertFalse(stillListed, "NFT should no longer be listed");
    }

    function testNFTTransferRestrictionsAfterMarketClose() public {
        // User1 achète des shares
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        vm.stopPrank();
        
        uint256 tokenId = 1;
        
        // Lister le NFT
        vm.startPrank(user1);
        betNFT.listNFT(tokenId, 0.1 ether);
        vm.stopPrank();
        
        // Fermer le marché (preliminary resolve)
        vm.warp(block.timestamp + 366 days);
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes);
        vm.stopPrank();
        
        // Essayer d'acheter le NFT après fermeture du marché
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        vm.expectRevert("Market must be open");
        betNFT.buyNFT{value: 0.1 ether}(tokenId);
        vm.stopPrank();
    }

    function testMultipleNFTsForSameUser() public {
        vm.startPrank(user1);
        usdc.approve(address(market), 5000 * 1e18);
        
        // Premier achat YES
        market.buyYes(100 * 1e18);
        
        // Deuxième achat NO
        market.buyNo(50 * 1e18);
        
        // Troisième achat YES
        market.buyYes(200 * 1e18);
        
        vm.stopPrank();
        
        // User1 devrait avoir 3 NFTs
        assertEq(betNFT.balanceOf(user1), 3, "User should have 3 NFTs");
        
        // Vérifier les métadonnées de chaque NFT
        (,, bool isYes1, ) = betNFT.betMetadata(1);
        (,, bool isYes2, ) = betNFT.betMetadata(2);
        (,, bool isYes3, ) = betNFT.betMetadata(3);
        
        assertTrue(isYes1, "First NFT should be YES");
        assertFalse(isYes2, "Second NFT should be NO");
        assertTrue(isYes3, "Third NFT should be YES");
    }

    function testNFTRedemptionAfterResolution() public {
        // Setup: User1 achète des shares YES
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        vm.stopPrank();
        
        uint256 tokenId = 1;
        
        // Résoudre le marché en faveur de YES
        vm.warp(block.timestamp + 366 days);
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes);
        market.finalResolve(PredictionMarket.Outcome.Yes, 100);
        vm.stopPrank();
        
        // User1 peut toujours posséder le NFT après résolution
        assertEq(betNFT.ownerOf(tokenId), user1, "User should still own NFT after resolution");
        
        // Et peut récupérer ses gains
        uint256 initialBalance = usdc.balanceOf(user1);
        vm.startPrank(user1);
        market.redeem();
        vm.stopPrank();
        uint256 finalBalance = usdc.balanceOf(user1);
        
        assertTrue(finalBalance > initialBalance, "User should receive winnings");
        
        // Le NFT existe toujours mais les shares sont à zéro dans le marché
        assertEq(market.yesBalance(user1), 0, "Market shares should be zero after redemption");
        assertEq(betNFT.ownerOf(tokenId), user1, "NFT should still exist as collectible");
    }

    function testNFTListingPermissions() public {
        // User1 achète des shares
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        vm.stopPrank();
        
        uint256 tokenId = 1;
        
        // User2 ne peut pas lister un NFT qu'il ne possède pas
        vm.startPrank(user2);
        vm.expectRevert("Not owner");
        betNFT.listNFT(tokenId, 0.1 ether);
        vm.stopPrank();
        
        // User1 peut lister son propre NFT
        vm.startPrank(user1);
        betNFT.listNFT(tokenId, 0.1 ether);
        vm.stopPrank();
        
        // Vérifier que c'est listé
        (, , , bool isListed) = betNFT.listings(tokenId);
        assertTrue(isListed, "NFT should be successfully listed");
    }

    // === NFT TESTS ===

    function testNFTMinting() public {
        // Acheter des shares devrait créer un NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        
        uint256 initialNFTBalance = betNFT.balanceOf(user1);
        market.buyYes(100 * 1e18);
        uint256 finalNFTBalance = betNFT.balanceOf(user1);
        
        // Un NFT devrait avoir été créé
        assertEq(finalNFTBalance, initialNFTBalance + 1, "Should mint 1 NFT");
        
        // Vérifier les métadonnées du NFT
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        (address nftMarket, uint256 nftShares, bool nftIsYes, uint256 nftTimestamp) = betNFT.betMetadata(tokenId);
        
        assertEq(nftMarket, address(market), "NFT should reference correct market");
        assertEq(nftShares, 100 * 1e18, "NFT should have correct shares");
        assertTrue(nftIsYes, "NFT should be YES position");
        assertTrue(nftTimestamp > 0, "NFT should have timestamp");
        
        vm.stopPrank();
    }

    function testNFTListing() public {
        // User1 achète des shares et reçoit un NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        uint256 listingPrice = 0.5 ether; // Prix en ETH
        
        // Lister le NFT
        betNFT.listNFT(tokenId, listingPrice);
        
        // Vérifier le listing
        (uint256 listedTokenId, uint256 listedPrice, address seller, bool active) = betNFT.listings(tokenId);
        assertEq(listedTokenId, tokenId, "Listed token ID should match");
        assertEq(listedPrice, listingPrice, "Listed price should match");
        assertEq(seller, user1, "Seller should be user1");
        assertTrue(active, "Listing should be active");
        
        vm.stopPrank();
    }

    function testNFTSecondaryMarketSale() public {
        // Setup: User1 achète des shares et liste son NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        uint256 listingPrice = 0.5 ether;
        
        betNFT.listNFT(tokenId, listingPrice);
        vm.stopPrank();
        
        // User2 achète le NFT
        uint256 user1InitialBalance = user1.balance;
        uint256 user1InitialYesShares = market.yesBalance(user1);
        uint256 user2InitialYesShares = market.yesBalance(user2);
        
        vm.deal(user2, 1 ether); // Donner de l'ETH à user2
        vm.startPrank(user2);
        
        betNFT.buyNFT{value: listingPrice}(tokenId);
        
        vm.stopPrank();
        
        // Vérifications après achat
        
        // 1. NFT transféré
        assertEq(betNFT.ownerOf(tokenId), user2, "NFT should be owned by user2");
        
        // 2. Shares transférées dans le marché
        assertEq(market.yesBalance(user1), user1InitialYesShares - 100 * 1e18, "User1 should lose YES shares");
        assertEq(market.yesBalance(user2), user2InitialYesShares + 100 * 1e18, "User2 should gain YES shares");
        
        // 3. Paiement transféré
        assertEq(user1.balance, user1InitialBalance + listingPrice, "User1 should receive payment");
        
        // 4. Listing désactivé
        (, , , bool active) = betNFT.listings(tokenId);
        assertFalse(active, "Listing should be inactive after sale");
    }

    function testNFTTradingBlockedAfterEndTime() public {
        // User1 achète et liste un NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        betNFT.listNFT(tokenId, 0.5 ether);
        vm.stopPrank();
        
        // Avancer le temps après endTime
        vm.warp(block.timestamp + 366 days);
        
        // Tentative d'achat du NFT devrait échouer
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        
        vm.expectRevert("Market ended");
        betNFT.buyNFT{value: 0.5 ether}(tokenId);
        
        vm.stopPrank();
        
        // De même, nouvelle tentative de listing devrait échouer
        vm.startPrank(user1);
        betNFT.cancelListing(tokenId); // Annuler le listing existant
        
        vm.expectRevert("Market ended");
        betNFT.listNFT(tokenId, 0.3 ether);
        
        vm.stopPrank();
    }

    function testNFTTradingBlockedAfterPreliminaryResolve() public {
        // User1 achète et liste un NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        betNFT.listNFT(tokenId, 0.5 ether);
        vm.stopPrank();
        
        // Avancer le temps et faire une résolution préliminaire
        vm.warp(block.timestamp + 366 days);
        vm.startPrank(admin);
        market.preliminaryResolve(PredictionMarket.Outcome.Yes);
        vm.stopPrank();
        
        // Tentative d'achat du NFT devrait échouer (marché fermé)
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        
        vm.expectRevert("Market must be open");
        betNFT.buyNFT{value: 0.5 ether}(tokenId);
        
        vm.stopPrank();
    }

    function testNFTListingCancellation() public {
        // User1 achète et liste un NFT
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        betNFT.listNFT(tokenId, 0.5 ether);
        
        // Vérifier que le listing est actif
        (, , , bool activeBefore) = betNFT.listings(tokenId);
        assertTrue(activeBefore, "Listing should be active initially");
        
        // Annuler le listing
        betNFT.cancelListing(tokenId);
        
        // Vérifier que le listing est inactif
        (, , , bool activeAfter) = betNFT.listings(tokenId);
        assertFalse(activeAfter, "Listing should be inactive after cancellation");
        
        vm.stopPrank();
    }

    function testNFTMetadataAndTokenURI() public {
        // User1 achète des shares YES
        vm.startPrank(user1);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyYes(100 * 1e18);
        
        uint256 tokenId = betNFT.tokenOfOwnerByIndex(user1, 0);
        
        // Tester les métadonnées
        (address nftMarket, uint256 nftShares, bool nftIsYes, uint256 nftTimestamp) = betNFT.betMetadata(tokenId);
        assertEq(nftMarket, address(market));
        assertEq(nftShares, 100 * 1e18);
        assertTrue(nftIsYes);
        assertTrue(nftTimestamp > 0);
        
        // Tester le tokenURI
        string memory tokenURI = betNFT.tokenURI(tokenId);
        assertTrue(bytes(tokenURI).length > 0, "TokenURI should not be empty");
        
        vm.stopPrank();
        
        // User2 achète des shares NO pour comparaison
        vm.startPrank(user2);
        usdc.approve(address(market), 1000 * 1e18);
        market.buyNo(50 * 1e18);
        
        uint256 tokenId2 = betNFT.tokenOfOwnerByIndex(user2, 0);
        
        (address nftMarket2, uint256 nftShares2, bool nftIsYes2, ) = betNFT.betMetadata(tokenId2);
        assertEq(nftMarket2, address(market));
        assertEq(nftShares2, 50 * 1e18);
        assertFalse(nftIsYes2, "Should be NO position");
        
        vm.stopPrank();
    }

    function testMultipleNFTsAndSecondaryTrading() public {
        // User1 fait plusieurs achats (devrait créer plusieurs NFTs)
        vm.startPrank(user1);
        usdc.approve(address(market), 5000 * 1e18);
        
        market.buyYes(100 * 1e18);
        market.buyNo(200 * 1e18);
        market.buyYes(50 * 1e18);
        
        // Vérifier qu'il a 3 NFTs
        assertEq(betNFT.balanceOf(user1), 3, "User1 should have 3 NFTs");
        
        // Lister deux NFTs à des prix différents
        uint256 tokenId1 = betNFT.tokenOfOwnerByIndex(user1, 0);
        uint256 tokenId2 = betNFT.tokenOfOwnerByIndex(user1, 1);
        
        betNFT.listNFT(tokenId1, 0.3 ether);
        betNFT.listNFT(tokenId2, 0.7 ether);
        
        vm.stopPrank();
        
        // User2 achète le NFT le moins cher
        vm.deal(user2, 2 ether);
        vm.startPrank(user2);
        
        uint256 user2InitialBalance = user2.balance;
        betNFT.buyNFT{value: 0.3 ether}(tokenId1);
        
        // Vérifier le transfert
        assertEq(betNFT.ownerOf(tokenId1), user2, "User2 should own tokenId1");
        assertEq(user2.balance, user2InitialBalance - 0.3 ether, "User2 should pay 0.3 ETH");
        assertEq(betNFT.balanceOf(user1), 2, "User1 should have 2 NFTs left");
        assertEq(betNFT.balanceOf(user2), 1, "User2 should have 1 NFT");
        
        vm.stopPrank();
    }

}
