// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Context} from "../../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {ICRARegistry} from "../interfaces/ICRARegistry.sol";

/// @title CRAAware
/// @notice Base contract that integrates with a CRA Registry to restrict functions to active CRA addresses
/// @dev Intended to be inherited by upgradeable contracts. Provides an initializer, an access modifier, and helpers.
/// @author Outbe Team
/// @custom:version 1.0.0
/// @custom:security-contact security@outbe.io
abstract contract CRAAware is Context, Initializable {
    /// @notice Reference to the CRA Registry contract
    /// @dev Must be set via the initializer or _setRegistry before using onlyActiveCRA
    ICRARegistry public craRegistry;

    /// @notice Initializer for CRAAware base contract
    /// @dev Should be called from the child contract's initializer. Reverts if _craRegistry is zero.
    /// @param _craRegistry Address of the CRA Registry implementing ICRARegistry
    function __CRAAware_init(address _craRegistry) internal onlyInitializing {
        _setRegistry(_craRegistry);
    }

    /// @notice Restricts a function so that only active CRAs in the registry can call it
    /// @dev Uses CRA registry's isCRAActive(msg.sender)
    modifier onlyActiveCRA() {
        _checkActiveCra();
        _;
    }

    /// @notice Checks that the caller is an active CRA in the registry
    /// @dev Reverts with "CRA not active" if msg.sender is not active
    function _checkActiveCra() internal view virtual {
        require(craRegistry.isCRAActive(_msgSender()), "CRA not active");
    }

    /// @notice Set the CRA registry reference
    /// @dev Internal helper used by the initializer. Reverts if zero address.
    /// @param _craRegistry Address of CRARegistry contract
    function _setRegistry(address _craRegistry) internal {
        require(_craRegistry != address(0), "CRARegistry address is zero");
        craRegistry = ICRARegistry(_craRegistry);
    }

    /// @notice Get the CRA registry address
    /// @return Address of the CRA Registry contract
    function registry() external view returns (address) {
        return address(craRegistry);
    }
}
