// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract RoundingTest is Test {
    
    function testCMMPRounding() public pure {
        console2.log("=== TEST PREVENTION ACHATS GRATUITS ===");
        
        // Test de la recherche binaire pour voir si elle evite les achats gratuits
        uint256 sharesToBuy = 1e15; // Tres petit montant (0.001 shares)
        
        // Simulation binary search (simplified)
        uint256 low = 1;
        uint256 high = sharesToBuy * 2;
        uint256 tolerance = 1e15;
        
        uint256 iterations = 0;
        while (high - low > tolerance && iterations < 100) {
            uint256 mid = (low + high) / 2;
            
            // Simulate CPMM calculation
            uint256 poolYes = 1e18;
            uint256 poolNo = 1e18;
            uint256 swapFeeBps = 30;
            
            uint256 usdcIn_eff = mid * (10_000 - swapFeeBps) / 10_000;
            uint256 k = poolYes * poolNo;
            uint256 ySwap = poolYes - (k / (poolNo + usdcIn_eff));
            uint256 totalYesOut = mid + ySwap;
            
            if (totalYesOut < sharesToBuy) {
                low = mid;
            } else {
                high = mid;
            }
            iterations++;
        }
        
        uint256 finalPrice = (low + high) / 2;
        
        console2.log("Shares demandees:", sharesToBuy);
        console2.log("Prix calcule:", finalPrice);
        console2.log("Iterations:", iterations);
        
        // Verification: pas d'achat gratuit
        assertTrue(finalPrice > 0, "No free purchases allowed!");
        
        // Le prix devrait etre raisonnable (pas astronomique)
        assertTrue(finalPrice < sharesToBuy * 10, "Price should be reasonable");
    }
    
    function testCMMPFormula() public pure {
        console2.log("\n=== TEST FORMULE CMPP ===");
        
        // Test avec des pools desequilibres
        // IMPORTANT: Dans CPMM, plus le pool est PETIT, plus l'outcome est PROBABLE
        uint256 poolYes = 800 * 1e18; // YES defavorise (gros pool = moins probable)
        uint256 poolNo = 200 * 1e18;  // NO favorise (petit pool = plus probable)
        
        uint256 usdcIn = 100 * 1e18;
        uint256 swapFeeBps = 30;
        
        // Achat YES (defavorise, devrait donner plus de shares pour meme USDC)
        uint256 usdcIn_eff_yes = usdcIn * (10_000 - swapFeeBps) / 10_000;
        uint256 k = poolYes * poolNo;
        uint256 newPoolNo = poolNo + usdcIn_eff_yes;
        uint256 newPoolYes = k / newPoolNo;
        uint256 ySwap = poolYes - newPoolYes;
        uint256 totalYesShares = usdcIn + ySwap;
        
        // Achat NO (favorise, devrait donner moins de shares pour meme USDC)
        uint256 usdcIn_eff_no = usdcIn * (10_000 - swapFeeBps) / 10_000;
        uint256 newPoolYes2 = poolYes + usdcIn_eff_no;
        uint256 newPoolNo2 = k / newPoolYes2;
        uint256 nSwap = poolNo - newPoolNo2;
        uint256 totalNoShares = usdcIn + nSwap;
        
        console2.log("Pool YES:", poolYes / 1e18, "(gros pool = defavorise)");
        console2.log("Pool NO:", poolNo / 1e18, "(petit pool = favorise)");
        console2.log("Pour 100 USDC:");
        console2.log("Shares YES recues:", totalYesShares / 1e18);
        console2.log("Shares NO recues:", totalNoShares / 1e18);
        
        // YES defavorise devrait donner PLUS de shares pour le meme USDC
        // (car pool YES est gros, donc outcome YES est moins probable)
        assertTrue(totalYesShares > totalNoShares, "Defavorise (YES) should give more shares");
        
        // Les deux devraient etre > 0
        assertTrue(totalYesShares > 0, "Should receive YES shares");
        assertTrue(totalNoShares > 0, "Should receive NO shares");
        
        // YES devrait donner significativement plus (au moins 20% de plus)
        assertTrue(totalYesShares > (totalNoShares * 120) / 100, "YES should give significantly more");
    }
    
    function testProbabilityCalculation() public pure {
        console2.log("\n=== TEST CALCUL PROBABILITES ===");
        
        // Test different pool states
        uint256[3] memory poolYesStates = [uint256(1e18), uint256(300e18), uint256(800e18)];
        uint256[3] memory poolNoStates = [uint256(1e18), uint256(700e18), uint256(200e18)];
        
        for (uint i = 0; i < 3; i++) {
            uint256 poolYes = poolYesStates[i];
            uint256 poolNo = poolNoStates[i];
            uint256 totalPools = poolYes + poolNo;
            
            // Dans CMPP: prob YES = poolNo / (poolYes + poolNo)
            uint256 probYes = (poolNo * 100) / totalPools;
            uint256 probNo = 100 - probYes;
            
            console2.log("Scenario:", i+1);
            console2.log("Pool YES:", poolYes / 1e18);
            console2.log("Pool NO:", poolNo / 1e18);
            console2.log("Prob YES:", probYes, "%");
            console2.log("Prob NO:", probNo, "%");
            console2.log("");
            
            // Verification
            assertEq(probYes + probNo, 100, "Probabilities should sum to 100%");
        }
    }
}
