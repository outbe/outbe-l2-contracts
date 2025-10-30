// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISoulBoundToken} from "./ISoulBoundToken.sol";

/// @title ITributeDraft Interface
/// @notice Aggregates multiple Consumption Units into a single Tribute Draft
interface ITributeDraft is ISoulBoundToken {
    struct TributeDraftEntity {
        /// @notice Owner of the tribute draft
        address owner;
        /// @notice Numeric currency code using ISO 4217
        uint16 settlementCurrency;
        /// @notice Worldwide day in a compact format YYYYMMDD (e.g., 20250923)
        uint32 worldwideDay;
        /// @notice Aggregated amount expressed in natural units (base currency units).
        uint64 settlementAmountBase;
        /// @notice Aggregated amount expressed in fractional units (atto, 1e-18). Must satisfy 0 <= amount < 1e18.
        uint128 settlementAmountAtto;
        /// @notice Hashes identifying linked consumption units
        uint256[] cuHashes;
        /// @notice Timestamp when the tribute draft was submitted
        uint256 submittedAt;
    }

    error EmptyArray();

    error NotFound(uint256 consumptionUnitIds);
    error NotSameOwner(uint256 consumptionUnitIds);
    error NotSettlementCurrencyCurrency();
    error NotSameWorldwideDay();

    function setConsumptionUnitAddress(address _consumptionUnitAddress) external;

    function getConsumptionUnitAddress() external view returns (address);

    function submit(uint256[] calldata consumptionUnitIds) external returns (uint256 tokenId);

    function getTokenData(uint256 tokenId) external view returns (TributeDraftEntity memory);
}
