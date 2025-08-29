// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PredictionMarketFactory.sol";
import "../src/PredictionMarket.sol";
import "../src/AdminManager.sol";
import "../src/Treasury.sol";
import "../src/BetNFT.sol";
import "../src/CastToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract ConfigurableFeesTest is Test {
    PredictionMarketFactory public factory;
    AdminManager public adminManager;
    Treasury public treasury;
    BetNFT public betNFT;
    CastToken public castToken;
    MockToken public mockToken;

    address public superAdmin = address(0x1);
    address public admin = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    function setUp() public {
        vm.startPrank(superAdmin);

        // Deploy contracts
        adminManager = new AdminManager(); // superAdmin is deployer
        treasury = new Treasury(address(adminManager));
        mockToken = new MockToken();
        castToken = new CastToken();
        betNFT = new BetNFT();

        factory = new PredictionMarketFactory(
            address(adminManager),
            address(treasury),
            address(mockToken),
            address(castToken),
            address(betNFT)
        );

        // Setup permissions
        castToken.authorizeMinter(address(factory));
        betNFT.transferOwnership(address(factory));
        adminManager.addAdmin(admin);

        // Distribute tokens
        mockToken.transfer(user1, 10000 * 10 ** 18);
        mockToken.transfer(user2, 10000 * 10 ** 18);

        vm.stopPrank();
    }

    function testDefaultFeeRate() public {
        // Check default fee rate
        assertEq(
            factory.getDefaultProtocolFeeRate(),
            200,
            "Default should be 2%"
        );

        // Create market and check its fee rate
        vm.startPrank(admin);
        mockToken.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test?",
            block.timestamp + 1 days
        );
        PredictionMarket market = PredictionMarket(factory.markets(marketId));

        assertEq(
            market.getProtocolFeeRate(),
            200,
            "Market should have default 2% fee"
        );
        vm.stopPrank();
    }

    function testSuperAdminCanChangeDefaultFeeRate() public {
        vm.startPrank(superAdmin);

        // Change default fee rate to 1%
        factory.setDefaultProtocolFeeRate(100);
        assertEq(
            factory.getDefaultProtocolFeeRate(),
            100,
            "Default should be 1%"
        );

        vm.stopPrank();

        // Create new market with new default
        vm.startPrank(admin);
        mockToken.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test2?",
            block.timestamp + 1 days
        );
        PredictionMarket market = PredictionMarket(factory.markets(marketId));

        assertEq(
            market.getProtocolFeeRate(),
            100,
            "New market should have 1% fee"
        );
        vm.stopPrank();
    }

    function testSuperAdminCanChangeMarketFeeRate() public {
        // Create market
        vm.startPrank(admin);
        mockToken.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test?",
            block.timestamp + 1 days
        );
        PredictionMarket market = PredictionMarket(factory.markets(marketId));
        vm.stopPrank();

        // Super admin changes this specific market's fee rate
        vm.startPrank(superAdmin);
        market.setProtocolFeeRate(300); // 3%
        assertEq(market.getProtocolFeeRate(), 300, "Market fee should be 3%");
        vm.stopPrank();
    }

    function testOnlySuperAdminCanChangeFees() public {
        // Regular admin cannot change default factory fee
        vm.startPrank(admin);
        vm.expectRevert("Only super admin");
        factory.setDefaultProtocolFeeRate(300);
        vm.stopPrank();

        // Regular user cannot change default factory fee
        vm.startPrank(user1);
        vm.expectRevert("Only super admin");
        factory.setDefaultProtocolFeeRate(300);
        vm.stopPrank();

        // Create market
        vm.startPrank(admin);
        mockToken.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test?",
            block.timestamp + 1 days
        );
        PredictionMarket market = PredictionMarket(factory.markets(marketId));
        vm.stopPrank();

        // Regular admin cannot change market fee rate
        vm.startPrank(admin);
        vm.expectRevert("Not super admin");
        market.setProtocolFeeRate(300);
        vm.stopPrank();

        // Regular user cannot change market fee rate
        vm.startPrank(user1);
        vm.expectRevert("Not super admin");
        market.setProtocolFeeRate(300);
        vm.stopPrank();
    }

    function testFeeRateLimits() public {
        vm.startPrank(superAdmin);

        // Cannot set fee rate above 10%
        vm.expectRevert("Fee rate too high");
        factory.setDefaultProtocolFeeRate(1001); // > 10%

        // Can set exactly 10%
        factory.setDefaultProtocolFeeRate(1000); // 10%
        assertEq(factory.getDefaultProtocolFeeRate(), 1000);

        vm.stopPrank();

        // Create market and test limits
        vm.startPrank(admin);
        mockToken.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test?",
            block.timestamp + 1 days
        );
        PredictionMarket market = PredictionMarket(factory.markets(marketId));
        vm.stopPrank();

        vm.startPrank(superAdmin);

        // Cannot set market fee above 10%
        vm.expectRevert("Fee rate too high");
        market.setProtocolFeeRate(1001);

        // Can set exactly 10%
        market.setProtocolFeeRate(1000);
        assertEq(market.getProtocolFeeRate(), 1000);

        vm.stopPrank();
    }

    function testActualFeesCollected() public {
        // Set fee to 5% to make it more visible
        vm.startPrank(superAdmin);
        factory.setDefaultProtocolFeeRate(500); // 5%
        vm.stopPrank();

        // Create market
        vm.startPrank(admin);
        mockToken.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test?",
            block.timestamp + 1 days
        );
        PredictionMarket market = PredictionMarket(factory.markets(marketId));
        vm.stopPrank();

        // Users bet
        vm.startPrank(user1);
        mockToken.approve(address(market), type(uint256).max);
        market.buyYes(100 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(market), type(uint256).max);
        market.buyNo(100 * 10 ** 18);
        vm.stopPrank();

        uint256 reserveBeforeResolution = market.reserve();
        uint256 treasuryBalanceBefore = mockToken.balanceOf(address(treasury));

        console.log(
            "Reserve before resolution:",
            reserveBeforeResolution / 10 ** 18
        );
        console.log(
            "Treasury balance before:",
            treasuryBalanceBefore / 10 ** 18
        );

        // Resolve market
        vm.warp(block.timestamp + 2 days);
        vm.startPrank(admin);
        market.resolveMarket(PredictionMarket.Outcome.Yes);
        vm.stopPrank();

        uint256 treasuryBalanceAfter = mockToken.balanceOf(address(treasury));
        uint256 feesCollected = treasuryBalanceAfter - treasuryBalanceBefore;
        uint256 expectedFees = (reserveBeforeResolution * 500) / 10000; // 5%

        console.log("Treasury balance after:", treasuryBalanceAfter / 10 ** 18);
        console.log("Fees collected:", feesCollected / 10 ** 18);
        console.log("Expected fees (5%):", expectedFees / 10 ** 18);

        assertEq(
            feesCollected,
            expectedFees,
            "Collected fees should match 5% of reserve"
        );
    }
}
