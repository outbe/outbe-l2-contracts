// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IConsumptionRecord Interface
/// @notice Interface for storing and managing consumption record hashes with metadata
/// @dev This interface defines functionality for submission, retrieval, and metadata management of consumption records
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionRecord {
    /// @notice Record information for a consumption record
    /// @dev Stores basic metadata about who submitted the record, when, who owns it, and includes metadata
    struct CrRecord {
        address submittedBy;
        /// @dev Address of the CRA that submitted this record
        uint256 submittedAt;
        /// @dev Timestamp when the record was submitted
        address owner;
        /// @dev Address of the owner of this consumption record
        string[] metadataKeys;
        /// @dev Array of metadata keys
        string[] metadataValues;
    }
    /// @dev Array of metadata values (matches keys array)

    /// @notice Emitted when a consumption record is submitted
    /// @param crHash The hash of the consumption record
    /// @param cra The address of the CRA that submitted the record
    /// @param timestamp The timestamp when the record was submitted
    event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp);

    /// @notice Emitted when metadata is added to a consumption record
    /// @param crHash The hash of the consumption record
    /// @param key The metadata key
    /// @param value The metadata value
    event MetadataAdded(bytes32 indexed crHash, string key, string value);

    /// @notice Emitted when a batch of consumption records is submitted
    /// @param batchSize The number of records in the batch
    /// @param cra The address of the CRA that submitted the batch
    /// @param timestamp The timestamp when the batch was submitted
    event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);

    /// @notice Thrown when trying to submit a record that already exists
    error AlreadyExists();

    /// @notice Thrown when a non-active CRA tries to submit a record
    error CRANotActive();

    /// @notice Thrown when an invalid hash (zero hash) is provided
    error InvalidHash();

    /// @notice Thrown when metadata keys and values arrays have different lengths
    error MetadataKeyValueMismatch();

    /// @notice Thrown when trying to add metadata with an empty key
    error EmptyMetadataKey();

    /// @notice Thrown when an invalid owner address (zero address) is provided
    error InvalidOwner();

    /// @notice Thrown when batch size exceeds the maximum allowed (100)
    error BatchSizeTooLarge();

    /// @notice Thrown when trying to submit an empty batch
    error EmptyBatch();

    /// @notice Submit a consumption record with optional metadata
    /// @dev Only active CRAs can submit records. Hash must be non-zero and unique.
    /// @param crHash The hash of the consumption record (must be non-zero)
    /// @param owner The owner of the consumption record (must be non-zero)
    /// @param keys Array of metadata keys (must match values array length)
    /// @param values Array of metadata values (must match keys array length)
    function submit(bytes32 crHash, address owner, string[] memory keys, string[] memory values) external;

    /// @notice Check if a consumption record exists
    /// @param crHash The hash to check
    /// @return true if the record exists, false otherwise
    function isExists(bytes32 crHash) external view returns (bool);

    /// @notice Get a consumption record by hash
    /// @param crHash The hash of the record
    /// @return CrRecord struct with complete record data
    function getRecord(bytes32 crHash) external view returns (CrRecord memory);

    /// @notice Set the CRA Registry contract address
    /// @dev Only callable by contract owner
    /// @param _craRegistry The address of the CRA Registry contract
    function setCraRegistry(address _craRegistry) external;

    /// @notice Get the current CRA Registry contract address
    /// @return The address of the CRA Registry contract
    function getCraRegistry() external view returns (address);

    /// @notice Get all consumption record hashes owned by a specific address
    /// @param owner The address of the owner
    /// @return Array of consumption record hashes owned by the address
    function getRecordsByOwner(address owner) external view returns (bytes32[] memory);

    /// @notice Submit a batch of consumption records with metadata
    /// @dev Only active CRAs can submit records. Maximum 100 records per batch. All hashes must be unique and non-zero.
    /// @param crHashes Array of consumption record hashes (each must be non-zero)
    /// @param owners Array of record owners (each must be non-zero, matches crHashes length)
    /// @param keysArray Array of metadata key arrays (matches crHashes length)
    /// @param valuesArray Array of metadata value arrays (matches crHashes length)
    function submitBatch(
        bytes32[] memory crHashes,
        address[] memory owners,
        string[][] memory keysArray,
        string[][] memory valuesArray
    ) external;
}
