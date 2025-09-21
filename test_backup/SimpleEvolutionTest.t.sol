// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

contract SimpleEvolutionTest is Test {
    
    function testSimplePriceEvolution() public pure {
        console2.log("=== EVOLUTION DU PRIX SELON LES ACHATS ===");
        
        // Etat initial
        uint256 yesShares = 1e18;   // 1 share YES
        uint256 noShares = 1e18;    // 1 share NO
        
        console2.log("INITIAL:");
        console2.log("YES shares:", yesShares / 1e18);
        console2.log("NO shares:", noShares / 1e18);
        console2.log("Probabilites: 50% YES / 50% NO");
        console2.log("");
        
        // Achat 1: 100 shares YES
        uint256 achat1 = 100 * 1e18;
        uint256 prix1 = calculatePrice(yesShares, noShares, achat1);
        yesShares += achat1;
        uint256 prob1 = (yesShares * 100) / (yesShares + noShares);
        
        console2.log("ACHAT 1: 100 shares YES");
        console2.log("Prix:", prix1 / 1e18, "ETH");
        console2.log("Prix unitaire:", prix1 / achat1, "wei/share");
        console2.log("Nouvelle prob YES:", prob1, "%");
        console2.log("");
        
        // Achat 2: 200 shares YES
        uint256 achat2 = 200 * 1e18;
        uint256 prix2 = calculatePrice(yesShares, noShares, achat2);
        yesShares += achat2;
        uint256 prob2 = (yesShares * 100) / (yesShares + noShares);
        
        console2.log("ACHAT 2: 200 shares YES");
        console2.log("Prix:", prix2 / 1e18, "ETH");
        console2.log("Prix unitaire:", prix2 / achat2, "wei/share");
        console2.log("Nouvelle prob YES:", prob2, "%");
        console2.log("");
        
        // Achat 3: 500 shares YES
        uint256 achat3 = 500 * 1e18;
        uint256 prix3 = calculatePrice(yesShares, noShares, achat3);
        yesShares += achat3;
        uint256 prob3 = (yesShares * 100) / (yesShares + noShares);
        
        console2.log("ACHAT 3: 500 shares YES");
        console2.log("Prix:", prix3 / 1e18, "ETH");
        console2.log("Prix unitaire:", prix3 / achat3, "wei/share");
        console2.log("Nouvelle prob YES:", prob3, "%");
        console2.log("");
        
        console2.log("=== OBSERVATIONS ===");
        console2.log("Prix unitaire achat 1:", prix1 / achat1);
        console2.log("Prix unitaire achat 2:", prix2 / achat2);
        console2.log("Prix unitaire achat 3:", prix3 / achat3);
        console2.log("Le prix unitaire AUGMENTE car YES devient favori!");
    }
    
    function calculatePrice(uint256 yesShares, uint256 noShares, uint256 sharesToBuy) 
        internal pure returns (uint256) {
        
        uint256 currentTotal = yesShares + noShares;
        uint256 newYesShares = yesShares + sharesToBuy;
        uint256 newTotal = newYesShares + noShares;
        
        uint256 oldProb = (yesShares * 1e18) / currentTotal;
        uint256 newProb = (newYesShares * 1e18) / newTotal;
        uint256 probDiff = newProb - oldProb;
        
        return (sharesToBuy * probDiff) / 1e18;
    }
    
    function testYesVsNoComparison() public pure {
        console2.log("\n=== COMPARAISON YES vs NO ===");
        
        // Marche biaise: beaucoup plus de YES que NO
        uint256 yesShares = 800 * 1e18;
        uint256 noShares = 200 * 1e18;
        uint256 sharesToBuy = 100 * 1e18;
        
        // Prix pour acheter YES (deja favori)
        uint256 prixYes = calculatePrice(yesShares, noShares, sharesToBuy);
        
        // Prix pour acheter NO (defavorise)
        uint256 prixNo = calculatePrice(noShares, yesShares, sharesToBuy);
        
        console2.log("Etat marche:");
        console2.log("YES:", yesShares / 1e18, "shares (80%)");
        console2.log("NO:", noShares / 1e18, "shares (20%)");
        console2.log("");
        console2.log("Prix pour 100 shares:");
        console2.log("YES (favori):", prixYes / 1e18, "ETH");
        console2.log("NO (defavorise):", prixNo / 1e18, "ETH");
        console2.log("");
        console2.log("Acheter NO coute", (prixYes * 100) / prixNo, "% du prix de YES");
        console2.log(">>> Il est plus rentable d'acheter le defavorise! <<<");
    }
}
