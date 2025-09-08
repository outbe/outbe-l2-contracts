// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICRARegistry} from "../interfaces/ICRARegistry.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title CRARegistryUpgradeable
/// @notice Upgradeable registry for managing Consumption Reflection Agents (CRAs)
/// @dev This contract provides a centralized registry for CRA management with owner-controlled access
/// @author Outbe Team
/// @custom:version 1.0.0
/// @custom:security-contact security@outbe.io
contract CRARegistryUpgradeable is ICRARegistry, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice Contract version
    string public constant VERSION = "1.0.0";

    /// @dev Mapping from CRA address to their information
    mapping(address => CraInfo) private cras;

    /// @dev Array of all registered CRA addresses for enumeration
    address[] private craList;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier craExists(address cra) {
        if (cras[cra].registeredAt == 0) revert CRANotFound();
        _;
    }

    /// @notice Initialize the registry
    /// @dev Sets the provided address as the initial owner
    /// @param _owner Address of the contract owner
    function initialize(address _owner) public initializer {
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __UUPSUpgradeable_init();
        _transferOwnership(_owner);
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
        return owner();
    }

    /// @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
