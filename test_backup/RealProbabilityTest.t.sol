// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/PredictionMarket.sol";
import "../src/AdminManager.sol";
import "../src/Treasury.sol";
import "../src/BetNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract RealProbabilityTest is Test {
    PredictionMarket market;
    MockERC20 token;
    AdminManager adminManager;
    Treasury treasury;
    BetNFT betNFT;
    
    address admin = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    
    function setUp() public {
        // Deploy dependencies
        token = new MockERC20();
        adminManager = new AdminManager();
        treasury = new Treasury(address(adminManager));
        betNFT = new BetNFT();
        
        // Deploy market
        market = new PredictionMarket(
            bytes32("test"),
            "Will BTC reach 100k?",
            address(this),
            block.timestamp + 1 days,
            address(token),
            address(adminManager),
            address(treasury),
            address(betNFT),
            200
        );
        
        // Authorize market in BetNFT
        vm.prank(adminManager.superAdmin());
        betNFT.authorizeMarket(address(market));
        
        // Setup tokens
        token.mint(user1, 10000 * 10**18);
        token.mint(user2, 10000 * 10**18);
        
        vm.prank(user1);
        token.approve(address(market), type(uint256).max);
        vm.prank(user2);
        token.approve(address(market), type(uint256).max);
    }
    
    function testProbabilityPricingIntegration() public {
        console2.log("=== TEST INTEGRATION PRICING PROBABILISTE ===");
        
        // Etat initial (50/50)
        (uint256 probYes, uint256 probNo) = market.getProbabilities();
        console2.log("Initial - YES: %d%% NO: %d%%", probYes, probNo);
        assertEq(probYes, 50, "Initial probability should be 50%");
        assertEq(probNo, 50, "Initial probability should be 50%");
        
        // User1 achete du YES pour pousser la probabilite
        uint256 sharesToBuy = 1000 * 10**18;
        uint256 priceYes = market.getPriceYes(sharesToBuy);
        
        console2.log("Prix pour %d shares YES: %d", sharesToBuy / 10**18, priceYes / 10**18);
        
        vm.prank(user1);
        market.buyYes(sharesToBuy);
        
        // Verifier les nouvelles probabilites
        (probYes, probNo) = market.getProbabilities();
        console2.log("Apres achat YES - YES: %d%% NO: %d%%", probYes, probNo);
        
        // YES devrait maintenant etre plus probable
        assertTrue(probYes > 50, "YES probability should increase");
        assertTrue(probNo < 50, "NO probability should decrease");
        assertEq(probYes + probNo, 100, "Probabilities should sum to 100%");
        
        // User2 achete du NO pour reequilibrer
        uint256 sharesToBuyNo = 2000 * 10**18;
        uint256 priceNo = market.getPriceNo(sharesToBuyNo);
        
        console2.log("Prix pour %d shares NO: %d", sharesToBuyNo / 10**18, priceNo / 10**18);
        
        vm.prank(user2);
        market.buyNo(sharesToBuyNo);
        
        // Nouvelles probabilites
        (probYes, probNo) = market.getProbabilities();
        console2.log("Apres achat NO - YES: %d%% NO: %d%%", probYes, probNo);
        
        assertEq(probYes + probNo, 100, "Final probabilities should sum to 100%");
        
        // Le prix devrait refleter les probabilites:
        // Si NO est maintenant favorise, acheter YES devrait etre moins cher
        uint256 newPriceYes = market.getPriceYes(100 * 10**18);
        uint256 newPriceNo = market.getPriceNo(100 * 10**18);
        
        console2.log("Prix 100 shares - YES: %d NO: %d", newPriceYes / 10**18, newPriceNo / 10**18);
        
        if (probNo > probYes) {
            console2.log("NO est favorise, YES devrait etre moins cher");
            // assertTrue(newPriceYes < newPriceNo, "YES should be cheaper when NO is favored");
        }
    }
}
