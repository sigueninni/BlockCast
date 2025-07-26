// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PredictionMarket.sol";
import "./AdminManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionMarketFactory {
    address public adminManager;
    IERC20 public castToken;
    IERC20 public collateral;
    address public betNFT;

    bool public isFactoryPaused;

    mapping(bytes32 => address) public markets;
    address[] public allMarkets;

    event MarketCreated(bytes32 indexed id, address market, string question);
    event FactoryPaused(bool paused);
    event BetNFTUpdated(address newBetNFT);
    event AdminManagerUpdated(address newAdminManager);

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
        address _collateral,
        address _castToken,
        address _betNFT
    ) {
        adminManager = _adminManager;
        collateral = IERC20(_collateral);
        castToken = IERC20(_castToken);
        betNFT = _betNFT;
    }

    function createMarket(string memory question, uint256 endTime) external factoryNotPaused returns (bytes32) {
        require(endTime > block.timestamp, "End time must be in the future");

        bytes32 id = keccak256(abi.encodePacked(question, block.timestamp, msg.sender));
        require(markets[id] == address(0), "Market already exists");

        PredictionMarket market = new PredictionMarket(
            id,
            question,
            msg.sender,
            endTime,
            address(collateral),
            adminManager,
            betNFT
        );

        markets[id] = address(market);
        allMarkets.push(address(market));

        // reward mais bloquer jusau resolve - a changer
        castToken.transfer(msg.sender, 100e18);

        emit MarketCreated(id, address(market), question);
        return id;
    }

    function pauseFactory(bool _paused) external onlyAdmin {
        isFactoryPaused = _paused;
        emit FactoryPaused(_paused);
    }

    function updateBetNFT(address _newBetNFT) external onlyAdmin {
        betNFT = _newBetNFT;
        emit BetNFTUpdated(_newBetNFT);
    }

    function updateAdminManager(address _newAdminManager) external onlyAdmin {
        adminManager = _newAdminManager;
        emit AdminManagerUpdated(_newAdminManager);
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }
}
