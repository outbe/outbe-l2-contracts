// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IConsumptionRecord Interface
/// @notice Interface for storing and managing consumption record hashes with metadata
/// @dev This interface defines functionality for submission, retrieval, and metadata management of consumption records
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionRecord {
    /// @notice Record information for a consumption record
    /// @dev Stores basic metadata about who submitted the record and when
    struct CrRecord {
        address submittedBy;      /// @dev Address of the CRA that submitted this record
        uint256 submittedAt;      /// @dev Timestamp when the record was submitted
    }

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

    /// @notice Submit a consumption record with optional metadata
    /// @dev Only active CRAs can submit records. Hash must be non-zero and unique.
    /// @param crHash The hash of the consumption record (must be non-zero)
    /// @param keys Array of metadata keys (must match values array length)
    /// @param values Array of metadata values (must match keys array length)
    function submit(bytes32 crHash, string[] memory keys, string[] memory values) external;

    /// @notice Check if a consumption record exists
    /// @param crHash The hash to check
    /// @return true if the record exists, false otherwise
    function isExists(bytes32 crHash) external view returns (bool);

    /// @notice Get basic details about a consumption record
    /// @param crHash The hash of the record
    /// @return CrRecord struct with submission details
    function getDetails(bytes32 crHash) external view returns (CrRecord memory);

    /// @notice Get a specific metadata value for a record
    /// @param crHash The hash of the record
    /// @param key The metadata key to retrieve
    /// @return The metadata value (empty string if key doesn't exist)
    function getMetadata(bytes32 crHash, string memory key) external view returns (string memory);

    /// @notice Get all metadata keys for a record
    /// @param crHash The hash of the record
    /// @return Array of metadata keys (empty array if no metadata)
    function getMetadataKeys(bytes32 crHash) external view returns (string[] memory);

    /// @notice Set the CRA Registry contract address
    /// @dev Only callable by contract owner
    /// @param _craRegistry The address of the CRA Registry contract
    function setCraRegistry(address _craRegistry) external;

    /// @notice Get the current CRA Registry contract address
    /// @return The address of the CRA Registry contract
    function getCraRegistry() external view returns (address);
}
