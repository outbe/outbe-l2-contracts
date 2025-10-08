// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title ICRAAware Interface
/// @notice Interface for contracts that integrate with a CRA Registry and restrict actions to active CRAs
/// @dev Implemented by base contract CRAAware; exposes registry management and a custom error used by modifiers
/// @author Outbe Team
/// @custom:version 1.0.0
/// @custom:security-contact security@outbe.io
interface ICRAAware {
    /// @notice Emitted when the CRA Registry reference is updated
    /// @param registry The new CRA Registry contract address
    event RegistryUpdated(address indexed registry);

    /// @notice Revert error used when caller is not an active CRA in the registry
    error CRANotActive();

    /// @notice Set the CRA Registry contract address
    /// @dev Only callable by contract owner
    /// @param _craRegistry Address of the CRA Registry contract (must not be zero)
    function setCRARegistry(address _craRegistry) external;

    /// @notice Get the current CRA Registry contract address
    /// @return registry Address of the CRA Registry contract
    function getCRARegistry() external view returns (address registry);
}
