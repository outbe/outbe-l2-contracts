// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../interfaces/ICRAAware.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ICRARegistry} from "../interfaces/ICRARegistry.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title CRAAware
/// @notice Base contract that integrates with a CRA Registry to restrict functions to active CRA addresses
/// @dev Intended to be inherited by upgradeable contracts. Provides an initializer, an access modifier, and helpers.
/// @author Outbe Team
abstract contract CRAAware is ICRAAware, OwnableUpgradeable {
    /// @notice Reference to the CRA Registry contract
    /// @dev Must be set via the initializer or _setRegistry before using onlyActiveCRA
    ICRARegistry public craRegistry;

    /// @notice Initializer for CRAAware base contract
    /// @dev Should be called from the child contract's initializer. Reverts if _craRegistry is zero.
    /// @param _craRegistry Address of the CRA Registry implementing ICRARegistry
    function __CRAAware_init(address _craRegistry) internal onlyInitializing {
        _setRegistry(_craRegistry);
        __Ownable_init();
    }

    /// @notice Restricts a function so that only active CRAs in the registry can call it
    /// @dev Uses CRA registry's isCRAActive(msg.sender)
    modifier onlyActiveCRA() {
        _checkActiveCra();
        _;
    }

    /// @notice Checks that the caller is an active CRA in the registry
    /// @dev Reverts with the custom error CRANotActive if msg.sender is not active
    function _checkActiveCra() internal view virtual {
        if (!craRegistry.isCRAActive(_msgSender())) revert CRANotActive();
    }

    /// @inheritdoc ICRAAware
    function setCRARegistry(address _craRegistry) external onlyOwner {
        _setRegistry(_craRegistry);
    }

    /// @notice Set the CRA registry reference
    /// @dev Internal helper used by the initializer. Reverts if zero address.
    /// @param _craRegistry Address of CRARegistry contract
    function _setRegistry(address _craRegistry) internal {
        require(_craRegistry != address(0), "CRARegistry address is zero");
        craRegistry = ICRARegistry(_craRegistry);
        emit RegistryUpdated(_craRegistry);
    }

    /// @inheritdoc ICRAAware
    function getCRARegistry() external view returns (address) {
        return address(craRegistry);
    }
}
