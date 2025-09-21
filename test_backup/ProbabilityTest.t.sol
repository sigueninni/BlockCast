// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract ProbabilityTest is Test {
    
    function testProbabilityCalculation() public pure {
        console2.log("=== TEST CALCUL PROBABILITES ===");
        
        // Scenario 1: 30% YES, 70% NO
        uint256 yesShares = 300e18;
        uint256 noShares = 700e18;
        uint256 totalShares = yesShares + noShares;
        
        uint256 probYes = (yesShares * 100) / totalShares;
        uint256 probNo = (noShares * 100) / totalShares;
        
        console2.log("YES shares:", yesShares / 1e18);
        console2.log("NO shares:", noShares / 1e18);
        console2.log("Probabilite YES:", probYes);
        console2.log("Probabilite NO:", probNo);
        console2.log("Somme:", probYes + probNo);
        
        assertEq(probYes, 30, "Probabilite YES incorrecte");
        assertEq(probNo, 70, "Probabilite NO incorrecte");
        assertEq(probYes + probNo, 100, "Somme incorrecte");
    }
    
    function testPricingFormula() public pure {
        console2.log("\n=== TEST FORMULE PRICING ===");
        
        // Etat initial: 30% YES, 70% NO
        uint256 yesShares = 300e18;
        uint256 noShares = 700e18;
        uint256 sharesToBuy = 100e18;
        
        uint256 currentTotal = yesShares + noShares;
        uint256 newYesShares = yesShares + sharesToBuy;
        uint256 newTotal = newYesShares + noShares;
        
        // Probabilites avant/apres
        uint256 oldProb = (yesShares * 1e18) / currentTotal;
        uint256 newProb = (newYesShares * 1e18) / newTotal;
        uint256 probDiff = newProb - oldProb;
        
        // Prix selon nouvelle formule
        uint256 price = (sharesToBuy * probDiff) / 1e18;
        
        console2.log("Avant: YES %d%% NO %d%%", (yesShares * 100) / currentTotal, (noShares * 100) / currentTotal);
        console2.log("Apres: YES %d%% NO %d%%", (newYesShares * 100) / newTotal, (noShares * 100) / newTotal);
        console2.log("Changement probabilite: %d points", (probDiff * 100) / 1e18);
        console2.log("Prix total: %d", price / 1e18);
        console2.log("Prix par share: %d", price / sharesToBuy);
        
        assertTrue(price > 0, "Prix doit etre positif");
        assertTrue(probDiff > 0, "Probabilite doit augmenter");
    }
}
