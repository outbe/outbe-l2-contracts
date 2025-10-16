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
        /// @notice Unique ID of the consumption unit
        bytes32 consumptionUnitId;
        /// @notice Owner of the consumption unit
        address owner;
        /// @notice Address of the CRA agent who submitted this consumption unit
        address submittedBy;
        /// @notice Timestamp when the consumption unit was submitted
        uint256 submittedAt;
        /// @notice Worldwide day in compact format (e.g., 20250923)
        uint32 worldwideDay;
        /// @notice Amount expressed in natural units (base currency units).
        uint64 settlementAmountBase;
        /// @notice Amount expressed in fractional units (atto, 1e-18). Must satisfy 0 <= amount < 1e18.
        uint128 settlementAmountAtto;
        /// @notice Numeric currency code using ISO 4217
        uint16 settlementCurrency;
        /// @notice Hashes identifying linked consumption records (unique per record)
        bytes32[] crHashes;
    }

    event Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp);

    error AlreadyExists();
    error ConsumptionRecordAlreadyExists();
    error InvalidHash();
    error InvalidOwner();
    error EmptyBatch();
    error BatchSizeTooLarge();
    error InvalidSettlementCurrency();
    error InvalidAmount();
    error InvalidConsumptionRecords();

    /// @notice Submit a single consumption unit record
    /// @dev Only active CRAs can submit. Hash must be non-zero and unique.
    /// @param cuHash Unique hash/ID of the consumption unit (must be non-zero)
    /// @param owner Owner of the consumption unit (must be non-zero)
    /// @param settlementCurrency ISO-4217 numeric currency code (must be non-zero)
    /// @param worldwideDay Worldwide day in ISO-8601 compact format (e.g., 20250923)
    /// @param settlementAmountBase Amount in base units (must be >= 0)
    /// @param settlementAmountAtto Amount in fractional units (0 <= amount < 1e18)
    /// @param hashes Linked consumption record hashes (each must be unique globally)
    function submit(
        bytes32 cuHash,
        address owner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        bytes32[] memory hashes
    ) external;

    /// @notice Check if a consumption unit exists
    /// @param cuHash The CU hash to check
    /// @return True if exists, false otherwise
    function isExists(bytes32 cuHash) external view returns (bool);

    /// @notice Get a consumption unit by hash
    /// @param cuHash The CU hash to retrieve
    /// @return ConsumptionUnitEntity struct with complete record data
    function getConsumptionUnit(bytes32 cuHash) external view returns (ConsumptionUnitEntity memory);

    /// @notice Get all consumption unit hashes owned by a specific address
    /// @param owner The owner address
    /// @return Array of CU hashes owned by the address
    function getConsumptionUnitsByOwner(address owner) external view returns (bytes32[] memory);
}
