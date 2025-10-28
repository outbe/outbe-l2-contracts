// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
ERC165Upgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol";
import {
MulticallUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {
PausableUpgradeable
} from "../../lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import {AddressUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";
import {IConsumptionRecord} from "../interfaces/IConsumptionRecord.sol";
import {ISoulBoundNFT} from "../interfaces/ISoulBoundNFT.sol";
import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {SoulBoundTokenBase} from "../interfaces/SoulBoundTokenBase.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/introspection/ERC165Upgradeable.sol";

/// @title ConsumptionRecordUpgradeable
/// @notice Upgradeable contract for storing consumption record hashes with metadata
/// @dev This contract allows active CRAs to submit consumption records with flexible metadata
/// @author Outbe Team
contract ConsumptionRecordUpgradeable is
    PausableUpgradeable,
    UUPSUpgradeable,
    CRAAware,
    SoulBoundTokenBase,
    IConsumptionRecord,
    MulticallUpgradeable
{
    /// @notice Contract version
    string public constant VERSION = "1.0.0";

    /// @notice Maximum number of records that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping from record hash to record details
    mapping(uint256 => ConsumptionRecordEntity) private _data;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the consumption record contract
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
    function supportsInterface(bytes4 interfaceId) public view virtual override (SoulBoundTokenBase, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IConsumptionRecord).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IConsumptionRecord
    function submit(uint256 tokenId, address recordOwner, string[] memory keys, bytes32[] memory values)
    external
    onlyActiveCRA
    whenNotPaused
    {
        _submit(tokenId, recordOwner, keys, values, block.timestamp);
    }

    /// @inheritdoc IConsumptionRecord
    function multicall(bytes[] calldata data)
    external
    override(IConsumptionRecord, MulticallUpgradeable)
    onlyActiveCRA
    whenNotPaused
    returns (bytes[] memory results)
    {
        uint256 n = data.length;
        if (n == 0) revert EmptyBatch();
        if (n > MAX_BATCH_SIZE) revert BatchSizeTooLarge();
        // Inline implementation of OZ Multicall to allow access control modifiers
        results = new bytes[](n);
        for (uint256 i = 0; i < n; i++) {
            if (bytes4(data[i]) != this.submit.selector) revert InvalidCall();
            results[i] = AddressUpgradeable.functionDelegateCall(address(this), data[i]);
        }
    }

    /// @inheritdoc IConsumptionRecord
    function getTokenData(uint256 tokenId) external override view returns (ConsumptionRecordEntity memory) {
        return _data[tokenId];
    }

    function _submit(
        uint256 tokenId,
        address tokenOwner,
        string[] memory keys,
        bytes32[] memory values,
        uint256 timestamp
    ) private {
        if (keys.length != values.length) revert InvalidMetadata("keys-values mismatch");
        for (uint256 i = 0; i < keys.length; i++) {
            if (bytes(keys[i]).length == 0) revert InvalidMetadata("empty key");
        }

        // mint the token
        _mint(_msgSender(), tokenOwner, tokenId);

        // Store the data
        _data[tokenId] = ConsumptionRecordEntity({
            submittedBy: _msgSender(),
            submittedAt: timestamp,
            owner: tokenOwner,
            metadataKeys: keys,
            metadataValues: values
        });
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
