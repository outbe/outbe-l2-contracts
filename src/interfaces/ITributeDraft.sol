// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title ITributeDraft Interface
/// @notice Aggregates multiple Consumption Units into a single Tribute Draft
interface ITributeDraft {
    struct TributeDraftEntity {
        bytes32 tributeDraftId;
        // owner of all aggregated consumption units
        address owner;
        // currency shared across all consumption units (ISO 4217)
        uint16 settlementCurrency;
        /// ISO 8601 format: 20250923
        uint32 worldwideDay;
        // aggregated settlement amount
        uint256 settlementAmountBase;
        uint256 settlementAmountAtto;
        // source CU ids
        bytes32[] cuHashes;
        uint256 submittedAt;
    }

    event Submitted(
        bytes32 indexed tdId, address indexed owner, address indexed submittedBy, uint256 cuCount, uint256 timestamp
    );

    error EmptyArray();
    error AlreadyExists();
    error NotFound(bytes32 cuHash);
    error NotSameOwner();
    error NotSettlementCurrencyCurrency();
    error NotSameWorldwideDay();

    function setConsumptionUnitAddress(address consumptionUnitAddress) external;
    function getConsumptionUnitAddress() external view returns (address);

    function submit(bytes32[] calldata cuHashes) external returns (bytes32 tdId);

    function getTributeDraft(bytes32 tdId) external view returns (TributeDraftEntity memory);
}
