// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Initializable} from "../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {Context} from "../../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {ICRARegistry} from "../interfaces/ICRARegistry.sol";

abstract contract CRAAware is Context, Initializable {
    /// @dev Reference to the CRA Registry contract
    ICRARegistry public craRegistry;

    function __CRAAware_init(address _craRegistry) internal onlyInitializing {
        _setRegistry(_craRegistry);
    }

    modifier onlyActiveCRA() {
        _checkActiveCra();
        _;
    }

    /**
     * @dev Throws if the sender is not an active CRA.
     */
    function _checkActiveCra() internal view virtual {
        require(craRegistry.isCRAActive(_msgSender()), "CRA not active");
    }

    function _setRegistry(address _craRegistry) internal {
        craRegistry = ICRARegistry(_craRegistry);
    }

    function registry() external view returns (address) {
        return address(craRegistry);
    }
}
