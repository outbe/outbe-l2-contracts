// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title IConsumptionUnit Interface
/// @notice Interface for storing and managing consumption unit records with settlement and nominal amounts
/// @dev Mirrors IConsumptionRecord flow but with CuRecord data structure
/// @author Outbe Team
/// @custom:version 0.0.1
interface IConsumptionUnit {
    /// @notice Record information for a consumption unit
    struct ConsumptionUnitEntity {
        /// @notice owner of the consumption unit
        address owner;
        /// @notice address of the CRA agent who submitted that consumption unit
        address submittedBy;
        /// @notice ISO 4217
        string settlementCurrency;
        /// ISO 8601
        string worldwideDay;
        /// @notice Amount expressed in natural units, `settlement_base_amount >= 0`
        uint64 settlementBaseAmount;
        /// @notice Amount expressed in fractional units, `0 >= settlement_atto_amount < 1e18`
        uint128 settlementAttoAmount;
        /// @notice Quantity expressed in natural units, `nominal_base_qty >= 0`
        uint64 nominalBaseQty;
        /// @notice Amount expressed in fractional units, `0 >= nominal_atto_qty < 1e18`
        uint128 nominalAttoQty;
        /// @notice Nominal currency from Consumption Records
        string nominalCurrency;
        /// @notice Hashes identifying consumption records batch (base32-encoded, unique per record)
        bytes32[] hashes;
        /// @notice timestamp
        uint256 submittedAt;
    }

    event Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp);
    event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);

    error AlreadyExists();
    error CrAlreadyExists();
    error CRANotActive();
    error InvalidHash();
    error InvalidOwner();
    error EmptyBatch();
    error BatchSizeTooLarge();
    error InvalidCurrency();
    error InvalidAmount();
    error ArrayLengthMismatch();

    function submit(
        bytes32 cuHash,
        address owner,
        string memory settlementCurrency,
        string memory worldwideDay,
        uint64 settlementBaseAmount,
        uint128 settlementAttoAmount,
        uint64 nominalBaseQty,
        uint128 nominalAttoQty,
        string memory nominalCurrency,
        bytes32[] memory hashes
    ) external;

    function submitBatch(
        bytes32[] memory cuHashes,
        address[] memory owners,
        string[] memory settlementCurrencies,
        string[] memory worldwideDays,
        uint64[] memory settlementBaseAmounts,
        uint128[] memory settlementAttoAmounts,
        uint64[] memory nominalBaseQtys,
        uint128[] memory nominalAttoQtys,
        string[] memory nominalCurrencies,
        bytes32[][] memory hashesArray
    ) external;

    function isExists(bytes32 cuHash) external view returns (bool);

    function getRecord(bytes32 cuHash) external view returns (ConsumptionUnitEntity memory);

    function setCraRegistry(address _craRegistry) external;

    function getCraRegistry() external view returns (address);

    function getRecordsByOwner(address owner) external view returns (bytes32[] memory);
}
