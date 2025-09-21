// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CastToken.sol";
import "../src/PredictionMarketFactory.sol";
import "../src/AdminManager.sol";
import "../src/Treasury.sol";
import "../src/BetNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract CastTokenTest is Test {
    CastToken public castToken;
    PredictionMarketFactory public factory;
    AdminManager public adminManager;
    Treasury public treasury;
    BetNFT public betNFT;
    MockERC20 public mockCollateral;

    address public admin = address(0x1);
    address public creator = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        adminManager = new AdminManager();
        treasury = new Treasury(address(adminManager));
        mockCollateral = new MockERC20();
        castToken = new CastToken();
        betNFT = new BetNFT();

        // Transfer ownership to admin
        castToken.transferOwnership(admin);
        // Note: BetNFT ownership transferred to factory after factory creation

        factory = new PredictionMarketFactory(
            address(adminManager),
            address(treasury),
            address(mockCollateral),
            address(castToken),
            address(betNFT)
        );

        // Authorize factory as minter
        castToken.authorizeMinter(address(factory));

        // Transfer BetNFT ownership to factory AFTER factory is created
        betNFT.transferOwnership(address(factory));

        vm.stopPrank();
    }

    function testCastTokenInitialState() public {
        assertEq(castToken.name(), "Cast Token");
        assertEq(castToken.symbol(), "CAST");
        assertEq(castToken.totalSupply(), 10_000_000 * 10 ** 18);
        assertEq(castToken.balanceOf(admin), 10_000_000 * 10 ** 18);
        assertEq(castToken.MAX_SUPPLY(), 100_000_000 * 10 ** 18);
    }

    function testOnlyAuthorizedMinterCanMint() public {
        vm.startPrank(user);
        vm.expectRevert("Not authorized minter");
        castToken.mint(user, 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testFactoryCanMintRewards() public {
        vm.startPrank(address(factory));
        castToken.mint(creator, 100 * 10 ** 18);
        assertEq(castToken.balanceOf(creator), 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testCreatorRewardIntegration() public {
        // Give some collateral to creator
        vm.startPrank(admin);
        mockCollateral.transfer(creator, 1000 * 10 ** 18);
        vm.stopPrank();

        // Creator creates a market
        vm.startPrank(creator);
        mockCollateral.approve(address(factory), 1000 * 10 ** 18);
        bytes32 marketId = factory.createMarket(
            "Test question?",
            block.timestamp + 1 days
        );
        address marketAddress = factory.markets(marketId);
        vm.stopPrank();

        // Simulate market resolution calling rewardCreator
        vm.prank(marketAddress);
        factory.rewardCreator(creator);

        // Check creator received CAST tokens
        assertEq(castToken.balanceOf(creator), 100 * 10 ** 18);
    }

    function testMaxSupplyLimit() public {
        vm.startPrank(admin);

        // Mint close to max supply
        uint256 amountToMint = castToken.MAX_SUPPLY() - castToken.totalSupply();
        castToken.ownerMint(admin, amountToMint);

        // Try to mint more than max supply
        vm.expectRevert("Exceeds max supply");
        castToken.ownerMint(admin, 1);

        vm.stopPrank();
    }

    function testBurnTokens() public {
        vm.startPrank(admin);
        uint256 initialBalance = castToken.balanceOf(admin);
        uint256 burnAmount = 1000 * 10 ** 18;

        castToken.burn(burnAmount);

        assertEq(castToken.balanceOf(admin), initialBalance - burnAmount);
        assertEq(castToken.totalSupply(), 10_000_000 * 10 ** 18 - burnAmount);
        vm.stopPrank();
    }

    function testAuthorizationManagement() public {
        vm.startPrank(admin);

        address newMinter = address(0x99);

        // Authorize new minter
        castToken.authorizeMinter(newMinter);
        assertTrue(castToken.authorizedMinters(newMinter));

        // New minter can mint
        vm.startPrank(newMinter);
        castToken.mint(user, 50 * 10 ** 18);
        assertEq(castToken.balanceOf(user), 50 * 10 ** 18);
        vm.stopPrank();

        // Revoke authorization
        vm.startPrank(admin);
        castToken.revokeMinter(newMinter);
        assertFalse(castToken.authorizedMinters(newMinter));

        // Revoked minter cannot mint
        vm.startPrank(newMinter);
        vm.expectRevert("Not authorized minter");
        castToken.mint(user, 50 * 10 ** 18);
        vm.stopPrank();
    }

    function testRemainingSupply() public {
        uint256 expectedRemaining = castToken.MAX_SUPPLY() -
            castToken.totalSupply();
        assertEq(castToken.remainingSupply(), expectedRemaining);

        // Mint some tokens
        vm.prank(admin);
        castToken.ownerMint(user, 1000 * 10 ** 18);

        assertEq(
            castToken.remainingSupply(),
            expectedRemaining - 1000 * 10 ** 18
        );
    }
}
