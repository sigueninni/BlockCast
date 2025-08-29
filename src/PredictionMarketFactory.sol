// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PredictionMarket.sol";
import "./AdminManager.sol";
import "./Treasury.sol";
import "./BetNFT.sol";
import "./CastToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionMarketFactory {
    address public adminManager;
    address public treasury;
    CastToken public castToken;
    IERC20 public collateral;
    BetNFT public betNFT;

    bool public isFactoryPaused;
    uint256 public defaultProtocolFeeRate = 200; // Default 2% for new markets

    mapping(bytes32 => address) public markets;
    address[] public allMarkets;

    event MarketCreated(bytes32 indexed id, address market, string question);
    event FactoryPaused(bool paused);
    event BetNFTUpdated(address newBetNFT);
    event AdminManagerUpdated(address newAdminManager);
    event DefaultProtocolFeeRateChanged(uint256 oldRate, uint256 newRate);

    modifier onlyAdmin() {
        require(AdminManager(adminManager).isAdmin(msg.sender), "Not admin");
        _;
    }

    modifier factoryNotPaused() {
        require(!isFactoryPaused, "Market creation paused");
        _;
    }

    constructor(
        address _adminManager,
        address _treasury,
        address _collateral,
        address _castToken,
        address _betNFT
    ) {
        adminManager = _adminManager;
        treasury = _treasury;
        collateral = IERC20(_collateral);
        castToken = CastToken(_castToken);
        betNFT = BetNFT(_betNFT);
    }

    function createMarket(
        string memory question,
        uint256 endTime
    ) external factoryNotPaused returns (bytes32) {
        require(endTime > block.timestamp, "End time must be in the future");

        bytes32 id = keccak256(
            abi.encodePacked(question, block.timestamp, msg.sender)
        );
        require(markets[id] == address(0), "Market already exists");

        PredictionMarket market = new PredictionMarket(
            id,
            question,
            msg.sender,
            endTime,
            address(collateral),
            adminManager,
            treasury,
            address(betNFT),
            defaultProtocolFeeRate
        );

        markets[id] = address(market);
        allMarkets.push(address(market));

        // Authorize the new market to mint NFTs
        betNFT.authorizeMarket(address(market));

        // Note: CAST reward will be given when market is resolved, not at creation

        emit MarketCreated(id, address(market), question);
        return id;
    }

    function pauseFactory(bool _paused) external onlyAdmin {
        isFactoryPaused = _paused;
        emit FactoryPaused(_paused);
    }

    function updateBetNFT(address _newBetNFT) external onlyAdmin {
        betNFT = BetNFT(_newBetNFT);
        emit BetNFTUpdated(_newBetNFT);
    }

    function updateAdminManager(address _newAdminManager) external onlyAdmin {
        adminManager = _newAdminManager;
        emit AdminManagerUpdated(_newAdminManager);
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }

    function rewardCreator(address creator) external {
        // Only markets can call this function
        require(isValidMarket(msg.sender), "Only markets can reward creators");

        // Mint 100 CAST tokens to the creator
        castToken.mint(creator, 100e18);
    }

    function isValidMarket(address market) public view returns (bool) {
        for (uint i = 0; i < allMarkets.length; i++) {
            if (allMarkets[i] == market) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Set default protocol fee rate for new markets (only super admin)
     */
    function setDefaultProtocolFeeRate(uint256 _newFeeRate) external {
        require(
            AdminManager(adminManager).superAdmin() == msg.sender,
            "Only super admin"
        );
        require(_newFeeRate <= 1000, "Fee rate too high"); // Max 10%

        uint256 oldRate = defaultProtocolFeeRate;
        defaultProtocolFeeRate = _newFeeRate;

        emit DefaultProtocolFeeRateChanged(oldRate, _newFeeRate);
    }

    /**
     * @dev Get default protocol fee rate
     */
    function getDefaultProtocolFeeRate() external view returns (uint256) {
        return defaultProtocolFeeRate;
    }
}
