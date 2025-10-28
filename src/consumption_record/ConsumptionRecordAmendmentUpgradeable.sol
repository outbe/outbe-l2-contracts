// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SoulBoundTokenBase} from "../interfaces/SoulBoundTokenBase.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {
    MulticallUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {
    PausableUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import {AddressUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";
import {IConsumptionRecordAmendment} from "../interfaces/IConsumptionRecordAmendment.sol";
import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title ConsumptionRecordAmendmentUpgradeable
/// @notice Upgradeable contract for storing consumption record amendment hashes with metadata
/// @dev This contract allows active CRAs to submit consumption record amendments with flexible metadata
/// @author Outbe Team
contract ConsumptionRecordAmendmentUpgradeable is
    PausableUpgradeable,
    UUPSUpgradeable,
    CRAAware,
    SoulBoundTokenBase,
    IConsumptionRecordAmendment,
    MulticallUpgradeable
{
    /// @notice Contract version
    string public constant VERSION = "1.0.0";

    /// @notice Maximum number of records that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping from amendment hash to amendment details
    mapping(uint256 => ConsumptionRecordAmendmentEntity) private _data;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the consumption record amendment contract
    /// @dev Sets the CRA registry address and specified owner
    /// @param _craRegistry Address of the CRA Registry contract
    /// @param _owner Address of the contract owner
    function initialize(address _craRegistry, address _owner) public initializer {
        require(_craRegistry != address(0), "CRA Registry cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __Base_initialize();
        __CRAAware_init(_craRegistry);
        __Multicall_init();
        _transferOwnership(_owner);
    }

    /// @inheritdoc SoulBoundTokenBase
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SoulBoundTokenBase, IERC165Upgradeable)
        returns (bool)
    {
        return interfaceId == type(IConsumptionRecordAmendment).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc MulticallUpgradeable
    function multicall(bytes[] calldata data)
        external
        override(IConsumptionRecordAmendment, MulticallUpgradeable)
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = AddressUpgradeable.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }

    /// @inheritdoc IConsumptionRecordAmendment
    function submit(uint256 tokenId, address tokenOwner, string[] memory keys, bytes32[] memory values)
        external
        onlyActiveCRA
        whenNotPaused
    {
        _submit(tokenId, tokenOwner, keys, values, block.timestamp);
    }

    function _submit(
        uint256 tokenId,
        address tokenOwner,
        string[] memory keys,
        bytes32[] memory values,
        uint256 timestamp
    ) internal {
        if (keys.length != values.length) revert InvalidMetadata("keys-values mismatch");
        for (uint256 i = 0; i < keys.length; i++) {
            if (bytes(keys[i]).length == 0) revert InvalidMetadata("empty key");
        }

        // mint the token
        _mint(_msgSender(), tokenOwner, tokenId);

        // Store the data
        _data[tokenId] = ConsumptionRecordAmendmentEntity({
            submittedBy: _msgSender(),
            submittedAt: timestamp,
            owner: tokenOwner,
            metadataKeys: keys,
            metadataValues: values
        });
    }

    /// @inheritdoc IConsumptionRecordAmendment
    function getTokenData(uint256 tokenId) external view override returns (ConsumptionRecordAmendmentEntity memory) {
        return _data[tokenId];
    }

    /// @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Pause contract actions
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause contract actions
    function unpause() external onlyOwner {
        _unpause();
    }
}
