// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AdminManager {
    mapping(address => bool) public isAdmin;
    address public superAdmin;

    constructor() {
        superAdmin = msg.sender;
        isAdmin[msg.sender] = true;
    }

    modifier onlySuperAdmin() {
        require(msg.sender == superAdmin, "Not super admin");
        _;
    }

    function addAdmin(address _admin) external onlySuperAdmin {
        isAdmin[_admin] = true;
    }

    function removeAdmin(address _admin) external onlySuperAdmin {
        isAdmin[_admin] = false;
    }
}
