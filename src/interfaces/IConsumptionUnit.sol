// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title IConsumptionUnit Interface
/// @notice Interface for storing and managing consumption unit records with settlement and nominal amounts
/// @dev Mirrors IConsumptionRecord flow but with ConsumptionUnitEntity data structure
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionUnit {
    /// @notice Record information for a consumption unit
    struct ConsumptionUnitEntity {
        /// @notice consumption unit hash id
        uint256 cuId;
        /// @notice Owner of the consumption unit
        address owner;
        /// @notice Address of the CRA agent who submitted this consumption unit
        address submittedBy;
        /// @notice Timestamp when the consumption unit was submitted
        uint256 submittedAt;
        /// @notice Worldwide day in a compact format YYYYMMDD (e.g., 20250923)
        uint32 worldwideDay;
        /// @notice Amount expressed in natural units (base currency units).
        uint64 settlementAmountBase;
        /// @notice Amount expressed in fractional units (atto, 1e-18). Must satisfy 0 <= amount < 1e18.
        uint128 settlementAmountAtto;
        /// @notice Numeric currency code using ISO 4217
        uint16 settlementCurrency;
        /// @notice Hashes identifying linked consumption records (unique per record)
        uint256[] crIds;
        /// @notice Hashes identifying linked consumption records amendments (unique per record)
        uint256[] amendmentCrIds;
    }

    /// @notice Thrown when an invalid owner address (zero address) is provided
    error InvalidOwner();

    error ConsumptionRecordAlreadyExists();
    error InvalidSettlementCurrency();
    error InvalidAmount();
    error InvalidConsumptionRecords();

    /// @notice Submit a single consumption unit record
    /// @dev Only active CRAs can submit. Hash must be non-zero and unique.
    /// @param cuId Unique hash/ID of the consumption unit
    /// @param tokenOwner Owner of the consumption unit (must be non-zero)
    /// @param settlementCurrency ISO-4217 numeric currency code (must be non-zero)
    /// @param worldwideDay Worldwide day in ISO-8601 compact format (e.g., 20250923)
    /// @param settlementAmountBase Amount in base units (must be >= 0)
    /// @param settlementAmountAtto Amount in fractional units (0 <= amount < 1e18)
    /// @param crIds Linked consumption record hashes (each must be unique globally)
    /// @param amendmentCrIds Linked consumption record amendment hashes (each must be unique globally)
    function submit(
        uint256 cuId,
        address tokenOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        uint256[] memory crIds,
        uint256[] memory amendmentCrIds
    ) external;

    /// @notice Multicall entry point allowing multiple submits in a single transaction
    /// @dev Restricted to active CRAs and when not paused.
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);

    /// @notice Get a consumption unit by hash
    /// @param cuId The CU hash to retrieve
    /// @return ConsumptionUnitEntity struct with complete record data
    function getData(uint256 cuId) external view returns (ConsumptionUnitEntity memory);

    /// @notice Returns a list of consumption units owned by the given address
    /// @param owner owner of the consumption units
    /// @param indexFrom inclusive index from
    /// @param indexTo inclusive index to
    /// @return array with complete records data
    function getConsumptionUnitsByOwner(address owner, uint256 indexFrom, uint256 indexTo)
        external
        view
        returns (ConsumptionUnitEntity[] memory);
}
