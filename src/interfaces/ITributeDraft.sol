// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title ITributeDraft Interface
/// @notice Aggregates multiple Consumption Units into a single Tribute Draft
interface ITributeDraft {
    struct TributeDraftEntity {
        /// @notice Unique ID of the tribute draft
        bytes32 tributeDraftId;
        /// @notice Owner of the tribute draft
        address owner;
        /// @notice Numeric currency code using ISO 4217
        uint16 settlementCurrency;
        /// @notice Worldwide day in compact format (e.g., 20250923)
        uint32 worldwideDay;
        /// @notice Aggregated amount expressed in natural units (base currency units).
        uint64 settlementAmountBase;
        /// @notice Aggregated amount expressed in fractional units (atto, 1e-18). Must satisfy 0 <= amount < 1e18.
        uint128 settlementAmountAtto;
        /// @notice Hashes identifying linked consumption units
        bytes32[] cuHashes;
        /// @notice Timestamp when the tribute draft was submitted
        uint256 submittedAt;
    }

    event Submitted(
        bytes32 indexed tdId, address indexed owner, address indexed submittedBy, uint32 cuCount, uint256 timestamp
    );

    error EmptyArray();
    error AlreadyExists();
    error NotFound(bytes32 cuHash);
    error NotSameOwner(bytes32 cuHash);
    error NotSettlementCurrencyCurrency();
    error NotSameWorldwideDay();

    function setConsumptionUnitAddress(address consumptionUnitAddress) external;
    function getConsumptionUnitAddress() external view returns (address);

    function submit(bytes32[] calldata cuHashes) external returns (bytes32 tdId);

    function getTributeDraft(bytes32 tdId) external view returns (TributeDraftEntity memory);
}
