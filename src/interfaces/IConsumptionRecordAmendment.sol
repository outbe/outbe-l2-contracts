// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISoulBoundToken} from "./ISoulBoundToken.sol";

/// @title IConsumptionRecordAmendment Interface
/// @notice Interface for storing and managing consumption record amendment hashes with metadata
/// @dev Mirrors IConsumptionRecord but for amendments
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionRecordAmendment is ISoulBoundToken {

    /// @notice Record information for a consumption record amendment
    /// @dev Stores basic metadata about who submitted the amendment, when, who owns it, and includes metadata
    struct ConsumptionRecordAmendmentEntity {
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

    /// @notice Submit a consumption record amendment with optional metadata
    /// @dev Only active CRAs can submit records. Hash must be non-zero and unique.
    /// @param tokenId The hash of the consumption record amendment (must be non-zero)
    /// @param tokenOwner The owner of the consumption record amendment (must be non-zero)
    /// @param keys Array of metadata keys (must match values array length)
    /// @param values Array of metadata values (must match keys array length)
    function submit(uint256 tokenId, address tokenOwner, string[] memory keys, bytes32[] memory values) external;

    /// @notice Multicall entry point allowing multiple submits in a single transaction
    /// @dev Restricted to active CRAs and when not paused.
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    /// @notice Get a consumption record amendment by hash
    /// @param tokenId id of the amendment record
    /// @return struct with complete amendment record data
    function getTokenData(uint256 tokenId) external view returns (ConsumptionRecordAmendmentEntity memory);
}

