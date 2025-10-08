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
    struct ConsumptionRecordEntity {
        /// @dev ID of consumption record
        bytes32 consumptionRecordId;
        /// @dev Address of the CRA that submitted this record
        address submittedBy;
        /// @dev Timestamp when the record was submitted
        uint256 submittedAt;
        /// @dev Address of the owner of this consumption record
        address owner;
        /// @dev Array of metadata keys
        string[] metadataKeys;
        /// @dev Array of metadata values (matches keys array)
        bytes32[] metadataValues;
    }

    /// @notice Emitted when a consumption record is submitted
    /// @param crHash The hash of the consumption record
    /// @param cra The address of the CRA that submitted the record
    /// @param timestamp The timestamp when the record was submitted
    event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp);

    /// @notice Emitted when a batch of consumption records is submitted
    /// @param batchSize The number of records in the batch
    /// @param cra The address of the CRA that submitted the batch
    /// @param timestamp The timestamp when the batch was submitted
    event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);

    /// @notice Thrown when trying to submit a record that already exists
    error AlreadyExists();

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
    function submit(bytes32 crHash, address owner, string[] memory keys, bytes32[] memory values) external;

    // TODO replace batching by Multicall extension,
    //      see https://portal.thirdweb.com/tokens/build/extensions/general/Multicall
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
        bytes32[][] memory valuesArray
    ) external;

    /// @notice Check if a consumption record exists
    /// @param crHash The hash to check
    /// @return true if the record exists, false otherwise
    function isExists(bytes32 crHash) external view returns (bool);

    /// @notice Get a consumption record by hash
    /// @param crHash The hash of the record
    /// @return CrRecord struct with complete record data
    function getConsumptionRecord(bytes32 crHash) external view returns (ConsumptionRecordEntity memory);

    /// @notice Set the CRA Registry contract address
    /// @dev Only callable by contract owner
    /// @param _craRegistry The address of the CRA Registry contract
    function setCRARegistry(address _craRegistry) external;

    /// @notice Get the current CRA Registry contract address
    /// @return The address of the CRA Registry contract
    function getCRARegistry() external view returns (address);

    // TODO optimize this call to reduce a number of tokens returned and pagination,
    //      See for example: https://docs.openzeppelin.com/contracts/4.x/api/token/ERC721#ierc721enumerable-2
    /// @notice Get all consumption record hashes owned by a specific address
    /// @param owner The address of the owner
    /// @return Array of consumption record hashes owned by the address
    function getConsumptionRecordsByOwner(address owner) external view returns (bytes32[] memory);
}
