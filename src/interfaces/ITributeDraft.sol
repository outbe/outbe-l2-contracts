// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IConsumptionUnit} from "./IConsumptionUnit.sol";

/// @title ITributeDraft Interface
/// @notice Aggregates multiple Consumption Units into a single Tribute Draft
interface ITributeDraft {
    struct TributeDraftEntity {
        // owner of all aggregated consumption units
        address owner;
        // currency shared across all consumption units (ISO 4217)
        string settlementCurrency;
        // aggregated settlement amount
        uint64 settlementBaseAmount;
        uint128 settlementAttoAmount;
        // source CU ids
        bytes32[] cuHashes;
        uint256 submittedAt;
    }

    event Minted(
        bytes32 indexed tdId, address indexed owner, address indexed submittedBy, uint256 cuCount, uint256 timestamp
    );

    error EmptyArray();
    error DuplicateId();
    error NotFound(bytes32 cuHash);
    error NotSameOwner();
    error NotSameCurrency();
    error AlreadyExists(bytes32 tdId);

    function initialize(address consumptionUnit) external;

    function mint(bytes32[] calldata cuHashes) external returns (bytes32 tdId);

    function get(bytes32 tdId) external view returns (TributeDraftEntity memory);

    function getConsumptionUnit() external view returns (address);
}
