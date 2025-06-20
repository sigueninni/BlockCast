// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract PredictionMarketFactory {
    // -------------------------------------------------------------------------
    // 1. Type Declarations
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 2. State Variables
    // -------------------------------------------------------------------------
    address[] public markets;
    mapping(address => bool) public isMarket;
    address public oracle; // we will not use in V1 but we can in V2

    // -------------------------------------------------------------------------
    // 3. Events
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 4. Errors
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 5. Modifiers
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // 6. Functions
    // -------------------------------------------------------------------------
    constructor() {
        // ...
    }

    // External functions
    function createMarket()
        external
        returns (bytes32 id, address marketAdress)
    {}

    // External functions
    // External functions that are view
    // ...
    // External functions that are pure
    // ...
    // Public functions
    // ...
    // Internal functions
    // ...
    // Private functions
    // ...
}
