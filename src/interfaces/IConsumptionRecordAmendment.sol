// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title IConsumptionRecordAmendment Interface
/// @notice Interface for storing and managing consumption record amendment hashes with metadata
/// @dev Mirrors IConsumptionRecord but for amendments
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionRecordAmendment {
    /// @notice Record information for a consumption record amendment
    /// @dev Stores basic metadata about who submitted the amendment, when, who owns it, and includes metadata
    struct ConsumptionRecordAmendmentEntity {
        /// @notice ID of consumption record amendment
        bytes32 consumptionRecordAmendmentId;
        /// @notice Address of the CRA that submitted this amendment
        address submittedBy;
        /// @notice Timestamp when the amendment was submitted
        uint256 submittedAt;
        /// @notice Address of the owner of this consumption record amendment
        address owner;
        /// @notice Array of metadata keys
        string[] metadataKeys;
        /// @notice Array of metadata values (matches keys array)
        bytes32[] metadataValues;
    }

    /// @notice Emitted when a consumption record amendment is submitted
    /// @param crAmendmentHash The hash of the consumption record amendment
    /// @param cra The address of the CRA that submitted the amendment
    /// @param timestamp The timestamp when the amendment was submitted
    event Submitted(bytes32 indexed crAmendmentHash, address indexed cra, uint256 timestamp);

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

    /// @notice Thrown when trying to submit an invalid multicall tx
    error InvalidCall();

    /// @notice Submit a consumption record amendment with optional metadata
    /// @dev Only active CRAs can submit records. Hash must be non-zero and unique.
    /// @param crAmendmentHash The hash of the consumption record amendment (must be non-zero)
    /// @param owner The owner of the consumption record amendment (must be non-zero)
    /// @param keys Array of metadata keys (must match values array length)
    /// @param values Array of metadata values (must match keys array length)
    function submit(bytes32 crAmendmentHash, address owner, string[] memory keys, bytes32[] memory values) external;

    /// @notice Multicall entry point allowing multiple submits in a single transaction
    /// @dev Restricted to active CRAs and when not paused.
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    /// @notice Check if a consumption record amendment exists
    /// @param crAmendmentHash The hash to check
    /// @return true if the amendment exists, false otherwise
    function isExists(bytes32 crAmendmentHash) external view returns (bool);

    /// @notice Get a consumption record amendment by hash
    /// @param crAmendmentHash The hash of the amendment
    /// @return ConsumptionRecordAmendmentEntity struct with complete amendment data
    function getConsumptionRecordAmendment(bytes32 crAmendmentHash)
        external
        view
        returns (ConsumptionRecordAmendmentEntity memory);

    /// @notice Get all consumption record amendment hashes owned by a specific address
    /// @param owner The address of the owner
    /// @return Array of consumption record amendment hashes owned by the address
    function getConsumptionRecordAmendmentsByOwner(address owner) external view returns (bytes32[] memory);
}
