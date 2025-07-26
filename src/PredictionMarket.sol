// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "./AdminManager.sol";

contract PredictionMarket {
    enum MarketStatus {
        Submited,
        Open,
        Paused,
        Resolved,
        Canceled,
        Refunded
    }
    enum Outcome {
        Unset,
        Yes,
        No
    }

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
    address public betNFT;

    uint256 public yesShares;
    uint256 public noShares;
    uint256 public reserve;

    mapping(address => uint256) public yesBalance;
    mapping(address => uint256) public noBalance;

    Outcome public resolvedOutcome;

    modifier onlyAdmin() {
        require(adminManager.isAdmin(msg.sender), "Not admin");
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
        address _betNFT
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
        betNFT = _betNFT;

        yesShares = 1e18;
        noShares = 1e18;
        reserve = 1e18;
    }

    function getPriceYes(uint256 sharesToBuy) public view returns (uint256) {
        return (reserve * sharesToBuy) / (yesShares + sharesToBuy);
    }

    function getPriceNo(uint256 sharesToBuy) public view returns (uint256) {
        return (reserve * sharesToBuy) / (noShares + sharesToBuy);
    }

    function buyYes(uint256 shares) external isOpen {
        uint256 cost = getPriceYes(shares);
        require(
            collateral.transferFrom(msg.sender, address(this), cost),
            "Transfer failed"
        );

        yesShares += shares;
        reserve += cost;
        yesBalance[msg.sender] += shares;
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
    }

    function resolveMarket(Outcome outcome) external onlyAdmin {
        require(block.timestamp >= marketInfo.endTime, "Too early");
        require(marketInfo.status == MarketStatus.Open, "Invalid status");

        marketInfo.status = MarketStatus.Resolved;
        resolvedOutcome = outcome;
    }

    function redeem() external {
        require(marketInfo.status == MarketStatus.Resolved, "Not resolved");

        uint256 payout;
        if (resolvedOutcome == Outcome.Yes) {
            payout = yesBalance[msg.sender];
            yesBalance[msg.sender] = 0;
        } else if (resolvedOutcome == Outcome.No) {
            payout = noBalance[msg.sender];
            noBalance[msg.sender] = 0;
        }

        require(payout > 0, "Nothing to redeem");
        require(collateral.transfer(msg.sender, payout), "Transfer failed");
    }

    function pauseMarket() external onlyAdmin {
        marketInfo.status = MarketStatus.Paused;
    }

    function setBetNFT(address _newBetNFT) external onlyAdmin {
        betNFT = _newBetNFT;
    }
}
