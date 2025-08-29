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

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AnalyzePricingTest is Test {
    function testNewAMMFormula() public pure {
        console2.log("=== NOUVELLE FORMULE AMM (Option 1) ===");

        // Simulons l'état après premier achat avec la nouvelle formule
        uint256 reserve = 1000 * 10 ** 18;
        uint256 yesShares = 1001 * 10 ** 18; // 1 initial + 1000 achetées
        uint256 noShares = 1 * 10 ** 18; // 1 initial

        console2.log("--- ETAT SIMULE ---");
        console2.log("reserve:", reserve / 10 ** 18);
        console2.log("yesShares:", yesShares / 10 ** 18);
        console2.log("noShares:", noShares / 10 ** 18);

        // Test différents montants d'achat
        uint256[4] memory amounts = [
            uint256(10 * 10 ** 18),
            uint256(50 * 10 ** 18),
            uint256(100 * 10 ** 18),
            uint256(500 * 10 ** 18)
        ];

        for (uint i = 0; i < amounts.length; i++) {
            uint256 sharesToBuy = amounts[i];
            console2.log("");
            console2.log("--- ACHAT DE", sharesToBuy / 10 ** 18, "SHARES ---");

            // Prix YES avec nouvelle formule
            uint256 currentTotal = yesShares + noShares;
            uint256 newYesShares = yesShares + sharesToBuy;
            uint256 newTotalYes = newYesShares + noShares;

            uint256 oldValueYes = (yesShares * reserve) / currentTotal;
            uint256 newValueYes = (newYesShares * reserve) / newTotalYes;
            uint256 priceYes = newValueYes - oldValueYes;

            // Prix NO avec nouvelle formule
            uint256 newNoShares = noShares + sharesToBuy;
            uint256 newTotalNo = yesShares + newNoShares;

            uint256 oldValueNo = (noShares * reserve) / currentTotal;
            uint256 newValueNo = (newNoShares * reserve) / newTotalNo;
            uint256 priceNo = newValueNo - oldValueNo;

            console2.log("Prix YES total:", priceYes / 10 ** 18);
            console2.log(
                "Prix YES moyen (x1000):",
                (priceYes * 1000) / sharesToBuy
            );
            console2.log("Prix NO total:", priceNo / 10 ** 18);
            console2.log(
                "Prix NO moyen (x1000):",
                (priceNo * 1000) / sharesToBuy
            );
            console2.log(
                "Somme moyens (x1000):",
                ((priceYes + priceNo) * 1000) / sharesToBuy
            );
        }

        console2.log("\n=== PROPRIETES DE LA NOUVELLE FORMULE ===");
        console2.log("1. Prix YES + Prix NO devrait etre plus equilibre");
        console2.log(
            "2. Plus il y a de shares d'un cote, plus ca devient cher"
        );
        console2.log("3. Prix degressif elimine (economie d'echelle limitee)");
    }

    function testEquilibriumPricing() public pure {
        console2.log("\n=== TEST EQUILIBRE (50/50) ===");

        // État équilibré
        uint256 reserve = 1000 * 10 ** 18;
        uint256 yesShares = 500 * 10 ** 18;
        uint256 noShares = 500 * 10 ** 18;
        uint256 sharesToBuy = 100 * 10 ** 18;

        console2.log(
            "Etat equilibre - YES:",
            yesShares / 10 ** 18,
            "NO:",
            noShares / 10 ** 18
        );

        // Prix YES
        uint256 currentTotal = yesShares + noShares;
        uint256 newYesShares = yesShares + sharesToBuy;
        uint256 newTotalYes = newYesShares + noShares;

        uint256 oldValueYes = (yesShares * reserve) / currentTotal;
        uint256 newValueYes = (newYesShares * reserve) / newTotalYes;
        uint256 priceYes = newValueYes - oldValueYes;

        // Prix NO
        uint256 newNoShares = noShares + sharesToBuy;
        uint256 newTotalNo = yesShares + newNoShares;

        uint256 oldValueNo = (noShares * reserve) / currentTotal;
        uint256 newValueNo = (newNoShares * reserve) / newTotalNo;
        uint256 priceNo = newValueNo - oldValueNo;

        console2.log(
            "Prix",
            sharesToBuy / 10 ** 18,
            "shares YES:",
            priceYes / 10 ** 18
        );
        console2.log(
            "Prix",
            sharesToBuy / 10 ** 18,
            "shares NO:",
            priceNo / 10 ** 18
        );
        console2.log("Ratio YES/NO:", (priceYes * 100) / priceNo, "%");
        console2.log("En equilibre, YES et NO devraient couter pareil");
    }
}
