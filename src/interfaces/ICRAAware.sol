// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface ICRAAware {
    event RegistryUpdated(address indexed registry);

    error CRANotActive();

    /// @notice Set the CRA Registry contract address
    /// @dev Only callable by contract owner
    /// @param _craRegistry Address of the CRA Registry contract
    function setCRARegistry(address _craRegistry) external;

    /// @notice Get the current CRA Registry contract address
    /// @return Address of the CRA Registry contract
    function getCRARegistry() external view returns (address);
}
