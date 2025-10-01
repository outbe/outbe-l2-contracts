// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title ICRARegistry Interface
/// @notice Interface for managing Consumption Reflection Agents (CRAs)
/// @dev This interface defines the core functionality for CRA registration, status management, and querying
/// @author Outbe Team
/// @custom:version 0.0.1
interface ICRARegistry {
    /// @notice Possible status values for a CRA
    /// @dev Used to control CRA permissions and visibility
    enum CRAStatus {
        Inactive,
        /// @dev CRA is registered but not active
        Active,
        /// @dev CRA is active and can submit consumption records
        Suspended
    }
    /// @dev CRA is temporarily suspended

    /// @notice Information about a registered CRA
    /// @dev Stores all relevant data for a CRA
    struct CRAInfo {
        string name;
        /// @dev Human-readable name of the CRA
        CRAStatus status;
        /// @dev Current status of the CRA
        uint256 registeredAt;
    }
    /// @dev Timestamp when CRA was registered

    /// @notice Emitted when a new CRA is registered
    /// @param cra The address of the registered CRA
    /// @param name The name of the registered CRA
    /// @param timestamp The timestamp of registration
    event CRARegistered(address indexed cra, string name, uint256 timestamp);

    /// @notice Emitted when a CRA's status is updated
    /// @param cra The address of the CRA
    /// @param oldStatus The previous status
    /// @param newStatus The new status
    /// @param timestamp The timestamp of the status update
    event CRAStatusUpdated(address indexed cra, CRAStatus oldStatus, CRAStatus newStatus, uint256 timestamp);

    /// @notice Thrown when trying to access a CRA that doesn't exist
    error CRANotFound();

    /// @notice Thrown when trying to register a CRA that's already registered
    error CRAAlreadyRegistered();

    /// @notice Thrown when an invalid CRA status is provided
    error InvalidCRAStatus();

    /// @notice Thrown when an unauthorized address tries to perform an admin action
    error UnauthorizedAccess();

    /// @notice Thrown when trying to register a CRA with an empty name
    error EmptyCRAName();

    /// @notice Register a new CRA
    /// @dev Only callable by contract owner
    /// @param cra The address of the CRA to register
    /// @param name The name of the CRA (must not be empty)
    function registerCRA(address cra, string calldata name) external;

    /// @notice Update the status of an existing CRA
    /// @dev Only callable by contract owner, CRA must exist
    /// @param cra The address of the CRA
    /// @param status The new status to set
    function updateCRAStatus(address cra, CRAStatus status) external;

    /// @notice Check if a CRA is currently active
    /// @dev Returns true only if CRA exists and has Active status
    /// @param cra The address of the CRA to check
    /// @return true if CRA is active, false otherwise
    function isCRAActive(address cra) external view returns (bool);

    /// @notice Get detailed information about a CRA
    /// @dev Reverts if CRA doesn't exist
    /// @param cra The address of the CRA
    /// @return CraInfo struct containing name, status, and registration timestamp
    function getCRAInfo(address cra) external view returns (CRAInfo memory);

    /// @notice Get addresses of all registered CRAs
    /// @dev Returns empty array if no CRAs are registered
    /// @return Array of CRA addresses in registration order
    function getAllCRAs() external view returns (address[] memory);
}
