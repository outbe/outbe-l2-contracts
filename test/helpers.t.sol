// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract MockCRARegistry {
    mapping(address => bool) public active;

    function setActive(address cra, bool isActive) external {
        active[cra] = isActive;
    }

    function isCRAActive(address cra) external view returns (bool) {
        return active[cra];
    }
}
