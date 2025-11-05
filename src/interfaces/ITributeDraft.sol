// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISoulBoundToken} from "./ISoulBoundToken.sol";

/// @title ITributeDraft Interface
/// @notice Aggregates multiple Consumption Units into a single Tribute Draft
interface ITributeDraft is ISoulBoundToken {
    event Submitted(
        address indexed minter,
        address indexed to,
        uint256 indexed id,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        uint16 settlementCurrency,
        uint256[] cuHashes
    );

    struct TributeDraftEntity {
        /// @notice tribute draft hash id
        uint256 tdId;
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
        uint256 createdAt;
    }

    error EmptyArray();

    error NotFound(uint256 consumptionUnitIds);
    error NotSameOwner(uint256 consumptionUnitIds);
    error NotSettlementCurrencyCurrency();
    error NotSameWorldwideDay();

    function setConsumptionUnitAddress(address _consumptionUnitAddress) external;

    function getConsumptionUnitAddress() external view returns (address);

    function submit(uint256[] calldata cuIds) external returns (uint256 tdId);

    /// @notice Returns full entity data by the given ID
    /// @param tdId The tribute draft hash to retrieve
    /// @return TributeDraftEntity struct with complete data
    function getData(uint256 tdId) external view returns (TributeDraftEntity memory);

    /// @notice Returns a list of tribute drafts owned by the given address
    /// @param owner owner of the tribute drafts
    /// @param indexFrom inclusive index from
    /// @param indexTo inclusive index to
    /// @return array with complete tribute draft data
    function getTributeDraftsByOwner(address owner, uint256 indexFrom, uint256 indexTo)
        external
        view
        returns (TributeDraftEntity[] memory);
}
