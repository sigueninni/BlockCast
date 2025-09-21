// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AdminManager.sol";
import "./Treasury.sol";
import "./BetNFT.sol";

interface IPredictionMarketFactory {
    function rewardCreator(address creator) external;
}

contract PredictionMarket {
    enum MarketStatus {
        Submited,
        Open,
        PendingResolution, // 🆕 Marché fermé, en attente résolution finale
        Resolved,
        Canceled
    }

    enum Outcome {
        Unset,
        Yes,
        No
    }

    // Events
    event ProtocolFeeRateChanged(
        uint256 oldRate,
        uint256 newRate,
        address changedBy
    );

    event PreliminaryResolution(Outcome outcome, uint256 timestamp);
    event FinalResolution(Outcome outcome, uint256 confidenceScore, uint256 timestamp);
    struct MarketInfo {
        bytes32 id;
        string question;
        address creator;
        uint256 endTime;
        MarketStatus status;
    }

    MarketInfo public marketInfo;
    IERC20 public collateral;
    AdminManager public adminManager;
    Treasury public treasury;
    IPredictionMarketFactory public factory;
    BetNFT public betNFT;

    uint256 public yesShares;
    uint256 public noShares;
    uint256 public reserve;
    uint256 public protocolFeeRate = 200; // Default 2% = 200/10000, configurable by super admin

    mapping(address => uint256) public yesBalance;
    mapping(address => uint256) public noBalance;

    Outcome public resolvedOutcome;
    
    // 🆕 Variables pour système de résolution en deux étapes
    Outcome public preliminaryOutcome;
    uint256 public confidenceScore;
    uint256 public preliminaryResolveTime;

    modifier onlyAdmin() {
        require(adminManager.isAdmin(msg.sender), "Not admin");
        _;
    }

    modifier onlySuperAdmin() {
        require(msg.sender == adminManager.superAdmin(), "Not super admin");
        _;
    }

    modifier isOpen() {
        require(marketInfo.status == MarketStatus.Open, "Market not open");
        require(block.timestamp < marketInfo.endTime, "Market closed");
        _;
    }

    constructor(
        bytes32 _id,
        string memory _question,
        address _creator,
        uint256 _endTime,
        address _collateral,
        address _adminManager,
        address _treasury,
        address _betNFT,
        uint256 _protocolFeeRate
    ) {
        marketInfo = MarketInfo({
            id: _id,
            question: _question,
            creator: _creator,
            endTime: _endTime,
            status: MarketStatus.Open
        });

        collateral = IERC20(_collateral);
        adminManager = AdminManager(_adminManager);
        treasury = Treasury(_treasury);
        factory = IPredictionMarketFactory(msg.sender); // Factory is the deployer
        betNFT = BetNFT(_betNFT);

        // Set protocol fee rate (validate it's not too high)
        require(_protocolFeeRate <= 1000, "Fee rate too high"); // Max 10%
        protocolFeeRate = _protocolFeeRate;

        // Initialize with equal virtual liquidity for balanced pricing
        yesShares = 100e18; // 100 YES shares
        noShares = 100e18; // 100 NO shares
        reserve = 0; // Start with 0 real reserve
    }

    // === SIMPLE POLYMARKET-STYLE PRICING ===

    function getCurrentPrice()
        public
        view
        returns (uint256 priceYes, uint256 priceNo)
    {
        // Logique simple: plus de YES shares = prix YES plus élevé
        uint256 total = yesShares + noShares;
        if (total == 0) {
            return (50e16, 50e16); // 0.5 each if no shares
        }

        // Prix YES = proportion de YES shares
        priceYes = (yesShares * 1e18) / total;

        // Prix NO = reste pour garantir total = 1.0
        priceNo = 1e18 - priceYes; // SIMPLE: toujours = 1.0 - priceYes
    }

    function getPriceYes(uint256 sharesToBuy) public view returns (uint256) {
        if (sharesToBuy == 0) return 0;

        // Système simple: prix moyen basé sur la proportion actuelle et future
        uint256 currentTotal = yesShares + noShares;
        uint256 futureTotal = currentTotal + sharesToBuy;

        uint256 currentPrice = (yesShares * 1e18) / currentTotal;
        uint256 futurePrice = ((yesShares + sharesToBuy) * 1e18) / futureTotal;

        // Prix moyen pour cet achat
        uint256 avgPrice = (currentPrice + futurePrice) / 2;

        return (avgPrice * sharesToBuy) / 1e18;
    }

    function getPriceNo(uint256 sharesToBuy) public view returns (uint256) {
        if (sharesToBuy == 0) return 0;

        // Même logique pour NO
        uint256 currentTotal = yesShares + noShares;
        uint256 futureTotal = currentTotal + sharesToBuy;

        uint256 currentPrice = (noShares * 1e18) / currentTotal;
        uint256 futurePrice = ((noShares + sharesToBuy) * 1e18) / futureTotal;

        // Prix moyen pour cet achat
        uint256 avgPrice = (currentPrice + futurePrice) / 2;

        return (avgPrice * sharesToBuy) / 1e18;
    }

    function buyYes(uint256 shares) external isOpen {
        uint256 cost = getPriceYes(shares);
        require(cost > 0, "Invalid cost");

        require(
            collateral.transferFrom(msg.sender, address(this), cost),
            "Transfer failed"
        );

        yesShares += shares;
        reserve += cost;
        yesBalance[msg.sender] += shares;

        // Mint NFT for this position
        betNFT.mintBetNFT(msg.sender, address(this), shares, true);
    }

    function buyNo(uint256 shares) external isOpen {
        uint256 cost = getPriceNo(shares);
        require(
            collateral.transferFrom(msg.sender, address(this), cost),
            "Transfer failed"
        );

        noShares += shares;
        reserve += cost;
        noBalance[msg.sender] += shares;

        // Mint NFT for this position
        betNFT.mintBetNFT(msg.sender, address(this), shares, false);
    }

    // 🆕 Première résolution : ferme juste le marché
    function preliminaryResolve(Outcome outcome) external onlyAdmin {
        require(block.timestamp >= marketInfo.endTime, "Too early");
        require(marketInfo.status == MarketStatus.Open, "Invalid status");

        marketInfo.status = MarketStatus.PendingResolution;
        preliminaryOutcome = outcome;
        preliminaryResolveTime = block.timestamp;

        emit PreliminaryResolution(outcome, block.timestamp);
    }

    // 🆕 Résolution finale : toute la logique de payout + rewards
    function finalResolve(Outcome outcome, uint256 _confidenceScore) external onlyAdmin {
        require(marketInfo.status == MarketStatus.PendingResolution, "Must be in pending resolution");
        require(_confidenceScore <= 100, "Confidence score must be <= 100");

        marketInfo.status = MarketStatus.Resolved;
        resolvedOutcome = outcome;
        confidenceScore = _confidenceScore;

        // Calculate and send protocol fees (configurable %)
        uint256 totalReserve = reserve;
        uint256 protocolFees = (totalReserve * protocolFeeRate) / 10000;

        if (protocolFees > 0) {
            require(
                collateral.approve(address(treasury), protocolFees),
                "Approval failed"
            );
            treasury.receiveFees(address(collateral), protocolFees);
            reserve -= protocolFees;
        }

        // Reward creator with CAST tokens only after successful resolution
        factory.rewardCreator(marketInfo.creator);

        emit FinalResolution(outcome, _confidenceScore, block.timestamp);
    }

    // DEPRECATED: Utiliser preliminaryResolve() puis finalResolve()
    function resolveMarket(Outcome outcome) external onlyAdmin {
        require(block.timestamp >= marketInfo.endTime, "Too early");
        require(marketInfo.status == MarketStatus.Open, "Invalid status");

        marketInfo.status = MarketStatus.Resolved;
        resolvedOutcome = outcome;

        // Calculate and send protocol fees (configurable %)
        uint256 totalReserve = reserve;
        uint256 protocolFees = (totalReserve * protocolFeeRate) / 10000;

        if (protocolFees > 0) {
            require(
                collateral.approve(address(treasury), protocolFees),
                "Approval failed"
            );
            treasury.receiveFees(address(collateral), protocolFees);
            reserve -= protocolFees;
        }

        // Reward creator with CAST tokens only after successful resolution
        factory.rewardCreator(marketInfo.creator);
    }

    function redeem() external {
        require(marketInfo.status == MarketStatus.Resolved, "Not resolved");

        uint256 userShares = 0;
        uint256 totalWinningShares = 0;

        if (resolvedOutcome == Outcome.Yes) {
            userShares = yesBalance[msg.sender];
            totalWinningShares = yesShares;
            yesBalance[msg.sender] = 0;
        } else if (resolvedOutcome == Outcome.No) {
            userShares = noBalance[msg.sender];
            totalWinningShares = noShares;
            noBalance[msg.sender] = 0;
        }

        require(userShares > 0, "Nothing to redeem");
        require(totalWinningShares > 0, "No winning shares");

        // Calculate proportional payout from remaining reserve (after fees)
        uint256 payout = (userShares * reserve) / totalWinningShares;
        require(payout > 0, "No payout available");
        require(collateral.transfer(msg.sender, payout), "Transfer failed");
    }

    function transferShares(
        address from,
        address to,
        uint256 shares,
        bool isYes
    ) external {
        require(
            msg.sender == address(betNFT),
            "Only BetNFT can transfer shares"
        );
        require(marketInfo.status == MarketStatus.Open, "Market not open");

        if (isYes) {
            require(yesBalance[from] >= shares, "Insufficient YES balance");
            yesBalance[from] -= shares;
            yesBalance[to] += shares;
        } else {
            require(noBalance[from] >= shares, "Insufficient NO balance");
            noBalance[from] -= shares;
            noBalance[to] += shares;
        }
    }

    function setBetNFT(address _newBetNFT) external onlyAdmin {
        betNFT = BetNFT(_newBetNFT);
    }

    /**
     * @dev Set protocol fee rate (only super admin can modify)
     * @param _newFeeRate New fee rate in basis points (200 = 2%, 100 = 1%, etc.)
     */
    function setProtocolFeeRate(uint256 _newFeeRate) external onlySuperAdmin {
        require(_newFeeRate <= 1000, "Fee rate too high"); // Max 10%
        uint256 oldFeeRate = protocolFeeRate;
        protocolFeeRate = _newFeeRate;

        emit ProtocolFeeRateChanged(oldFeeRate, _newFeeRate, msg.sender);
    }

    /**
     * @dev Get current protocol fee rate
     */
    function getProtocolFeeRate() external view returns (uint256) {
        return protocolFeeRate;
    }

    function getMarketInfo() external view returns (MarketInfo memory) {
        return marketInfo;
    }

    // === PROBABILITY FUNCTIONS ===

    function getProbabilities()
        external
        view
        returns (uint256 probYes, uint256 probNo)
    {
        // Dans notre système simple: probabilité = prix
        (uint256 priceYes, ) = getCurrentPrice();

        // Convertir de 18 decimals vers pourcentage (0-100)
        probYes = (priceYes * 100) / 1e18;
        probNo = 100 - probYes; // Garantit que probYes + probNo = 100
    }

    // === FONCTIONS UTILITAIRES POUR SYSTÈME DE RÉSOLUTION ===
    
    function isPendingResolution() external view returns (bool) {
        return marketInfo.status == MarketStatus.PendingResolution;
    }
    
    function getPreliminaryOutcome() external view returns (Outcome) {
        return preliminaryOutcome;
    }
    
    function getConfidenceScore() external view returns (uint256) {
        return confidenceScore;
    }
}
