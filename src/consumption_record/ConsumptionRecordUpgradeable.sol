// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IConsumptionRecord} from "../interfaces/IConsumptionRecord.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";

/// @title ConsumptionRecordUpgradeable
/// @notice Upgradeable contract for storing consumption record hashes with metadata
/// @dev This contract allows active CRAs to submit consumption records with flexible metadata
/// @author Outbe Team
/// @custom:version 1.0.0
/// @custom:security-contact security@outbe.io
contract ConsumptionRecordUpgradeable is
    IConsumptionRecord,
    Initializable,
    CRAAware,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice Contract version
    string public constant VERSION = "1.0.0";

    /// @notice Maximum number of records that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping from record hash to record details
    mapping(bytes32 => ConsumptionRecordEntity) public consumptionRecords;

    /// @dev Mapping from owner address to array of record hashes they own
    mapping(address => bytes32[]) public ownerRecords;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier validCrHash(bytes32 crHash) {
        if (crHash == bytes32(0)) revert InvalidHash();
        _;
    }

    modifier validOwner(address _owner) {
        if (_owner == address(0)) revert InvalidOwner();
        _;
    }

    /// @notice Initialize the consumption record contract
    /// @dev Sets the CRA registry address and specified owner
    /// @param _craRegistry Address of the CRA Registry contract
    /// @param _owner Address of the contract owner
    function initialize(address _craRegistry, address _owner) public initializer {
        require(_craRegistry != address(0), "CRA Registry cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __UUPSUpgradeable_init();
        __CRAAware_init(_craRegistry);
        _transferOwnership(_owner);
    }

    /// @notice Internal function to add a single consumption record
    /// @param crHash The hash of the consumption record
    /// @param recordOwner The owner of the record
    /// @param keys Array of metadata keys
    /// @param values Array of metadata values
    /// @param timestamp The timestamp to use for submission
    function _addRecord(
        bytes32 crHash,
        address recordOwner,
        string[] memory keys,
        bytes32[] memory values,
        uint256 timestamp
    ) internal {
        // Validate record parameters
        if (crHash == bytes32(0)) revert InvalidHash();
        if (recordOwner == address(0)) revert InvalidOwner();
        if (isExists(crHash)) revert AlreadyExists();
        if (keys.length != values.length) revert MetadataKeyValueMismatch();

        // Validate metadata keys
        for (uint256 i = 0; i < keys.length; i++) {
            if (bytes(keys[i]).length == 0) revert EmptyMetadataKey();
        }

        // Store the record
        consumptionRecords[crHash] = ConsumptionRecordEntity({
            consumptionRecordId: crHash,
            submittedBy: msg.sender,
            submittedAt: timestamp,
            owner: recordOwner,
            metadataKeys: keys,
            metadataValues: values
        });

        // Add record hash to owner's list
        ownerRecords[recordOwner].push(crHash);

        // Emit submission event
        emit Submitted(crHash, msg.sender, timestamp);
    }

    /// @inheritdoc IConsumptionRecord
    function submit(bytes32 crHash, address recordOwner, string[] memory keys, bytes32[] memory values)
        external
        onlyActiveCRA
    {
        _addRecord(crHash, recordOwner, keys, values, block.timestamp);
    }

    /// @inheritdoc IConsumptionRecord
    function submitBatch(
        bytes32[] memory crHashes,
        address[] memory owners,
        string[][] memory keysArray,
        bytes32[][] memory valuesArray
    ) external onlyActiveCRA {
        uint256 batchSize = crHashes.length;

        // Validate batch size
        if (batchSize == 0) revert EmptyBatch();
        if (batchSize > MAX_BATCH_SIZE) revert BatchSizeTooLarge();

        // Validate array lengths match
        if (owners.length != batchSize) revert MetadataKeyValueMismatch();
        if (keysArray.length != batchSize) revert MetadataKeyValueMismatch();
        if (valuesArray.length != batchSize) revert MetadataKeyValueMismatch();

        uint256 timestamp = block.timestamp;

        // Process each record in the batch using the internal function
        for (uint256 i = 0; i < batchSize; i++) {
            _addRecord(crHashes[i], owners[i], keysArray[i], valuesArray[i], timestamp);
        }

        // Emit batch submission event
        emit BatchSubmitted(batchSize, msg.sender, timestamp);
    }

    /// @inheritdoc IConsumptionRecord
    function isExists(bytes32 crHash) public view returns (bool) {
        return consumptionRecords[crHash].submittedBy != address(0);
    }

    /// @inheritdoc IConsumptionRecord
    function getConsumptionRecord(bytes32 crHash) external view returns (ConsumptionRecordEntity memory) {
        return consumptionRecords[crHash];
    }

    /// @inheritdoc IConsumptionRecord
    function setCRARegistry(address _craRegistry) external onlyOwner {
        _setRegistry(_craRegistry);
    }

    /// @inheritdoc IConsumptionRecord
    function getCRARegistry() external view returns (address) {
        return address(craRegistry);
    }

    /// @inheritdoc IConsumptionRecord
    function getConsumptionRecordsByOwner(address _owner) external view returns (bytes32[] memory) {
        return ownerRecords[_owner];
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
