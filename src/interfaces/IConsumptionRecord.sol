// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISoulBoundToken} from "./ISoulBoundToken.sol";

/// @title IConsumptionRecord Interface
/// @notice Interface for storing and managing consumption record hashes with metadata
/// @dev This interface defines functionality for submission, retrieval, and metadata management of consumption records
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionRecord is ISoulBoundToken {
    /// @notice Record information for a consumption record
    /// @dev Stores basic metadata about who submitted the record, when, who owns it, and includes metadata
    struct ConsumptionRecordEntity {
        /// @notice consumption record hash id
        uint256 crId;
        /// @notice Address of the CRA that submitted this record
        address submittedBy;
        /// @notice Timestamp when the record was submitted
        uint256 submittedAt;
        /// @notice Address of the owner of this consumption record
        address owner;
        /// @notice Array of metadata keys
        string[] metadataKeys;
        /// @notice Array of metadata values (matches keys array)
        bytes32[] metadataValues;
    }

    /// @notice Thrown when the submitted metadata is invalid
    error InvalidMetadata(string reason);

    /// @notice Submit a consumption record with optional metadata
    /// @dev Only active CRAs can submit records. Hash must be non-zero and unique.
    /// @param crId The hash of the consumption record (must be non-zero)
    /// @param owner The owner of the consumption record (must be non-zero)
    /// @param keys Array of metadata keys (must match values array length)
    /// @param values Array of metadata values (must match keys array length)
    function submit(uint256 crId, address owner, string[] memory keys, bytes32[] memory values) external;

    /// @notice Multicall entry point allowing multiple submits in a single transaction
    /// @dev Restricted to active CRAs and when not paused.
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    /// @notice Get a consumption record by hash
    /// @param crId id of the record
    /// @return struct with complete record data
    function getData(uint256 crId) external view returns (ConsumptionRecordEntity memory);

    /// @notice Returns a list of consumption records owned by the given address
    /// @param owner owner of the consumption records
    /// @param indexFrom inclusive index from
    /// @param indexTo inclusive index to
    /// @return array with complete records data
    function getConsumptionRecordsByOwner(address owner, uint256 indexFrom, uint256 indexTo)
        external
        view
        returns (ConsumptionRecordEntity[] memory);
}
