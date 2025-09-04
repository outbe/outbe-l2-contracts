// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICRARegistry} from "../interfaces/ICRARegistry.sol";

/// @title CRARegistry
/// @notice Registry for managing Consumption Reflection Agents (CRAs)
/// @dev This contract provides a centralized registry for CRA management with owner-controlled access
/// @author Outbe Team
/// @custom:version 0.0.1
/// @custom:security-contact security@outbe.io
contract CRARegistry is ICRARegistry {
    /// @notice Contract version
    string public constant VERSION = "0.0.1";
    
    /// @dev Mapping from CRA address to their information
    mapping(address => CraInfo) private cras;
    
    /// @dev Array of all registered CRA addresses for enumeration
    address[] private craList;
    
    /// @dev Contract owner who can register and manage CRAs
    address private owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedAccess();
        _;
    }

    modifier craExists(address cra) {
        if (cras[cra].registeredAt == 0) revert CRANotFound();
        _;
    }

    /// @notice Initialize the registry with the specified owner
    /// @dev Sets the provided address as the initial owner
    /// @param _owner Address of the contract owner
    constructor(address _owner) {
        require(_owner != address(0), "Owner cannot be zero address");
        owner = _owner;
    }

    /// @inheritdoc ICRARegistry
    function registerCra(address cra, string calldata name) external onlyOwner {
        if (cras[cra].registeredAt != 0) revert CRAAlreadyRegistered();
        if (bytes(name).length == 0) revert EmptyCRAName();

        cras[cra] = CraInfo({name: name, status: CRAStatus.Active, registeredAt: block.timestamp});

        craList.push(cra);

        emit CRARegistered(cra, name, block.timestamp);
    }

    /// @inheritdoc ICRARegistry
    function updateCraStatus(address cra, CRAStatus status) external onlyOwner craExists(cra) {
        CRAStatus oldStatus = cras[cra].status;
        cras[cra].status = status;

        emit CRAStatusUpdated(cra, oldStatus, status, block.timestamp);
    }

    /// @inheritdoc ICRARegistry
    function isCraActive(address cra) external view returns (bool) {
        return cras[cra].registeredAt != 0 && cras[cra].status == CRAStatus.Active;
    }

    /// @inheritdoc ICRARegistry
    function getCraInfo(address cra) external view craExists(cra) returns (CraInfo memory) {
        return cras[cra];
    }

    /// @inheritdoc ICRARegistry
    function getAllCras() external view returns (address[] memory) {
        return craList;
    }

    /// @notice Get the current owner of the contract
    /// @return The address of the contract owner
    function getOwner() external view returns (address) {
        return owner;
    }
}
