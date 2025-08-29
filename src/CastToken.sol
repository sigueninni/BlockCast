// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CastToken is ERC20, Ownable {
    // Maximum supply: 100 million tokens
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18;

    // Mapping to track authorized minters (like PredictionMarketFactory)
    mapping(address => bool) public authorizedMinters;

    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender], "Not authorized minter");
        _;
    }

    constructor() ERC20("Cast Token", "CAST") Ownable(msg.sender) {
        // Mint initial supply to deployer for distribution
        _mint(msg.sender, 10_000_000 * 10 ** 18); // 10M initial supply
    }

    /**
     * @dev Authorize an address to mint tokens (e.g., PredictionMarketFactory)
     */
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /**
     * @dev Revoke minting authorization from an address
     */
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /**
     * @dev Mint tokens to reward market creators (only by authorized minters)
     */
    function mint(address to, uint256 amount) external onlyAuthorizedMinter {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    /**
     * @dev Owner can mint tokens for special distributions
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens to reduce supply
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Get remaining mintable supply
     */
    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
}
