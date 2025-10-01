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
        /// @dev ID of consumption record
        bytes32 consumptionUnitId;
        /// @notice owner of the consumption unit
        address owner;
        /// @notice address of the CRA agent who submitted that consumption unit
        address submittedBy;
        /// @notice timestamp
        uint256 submittedAt;
        /// ISO 8601
        uint32 worldwideDay;
        /// @notice Amount expressed in natural units, `settlement_base_amount >= 0`
        uint256 settlementAmountBase;
        /// @notice Amount expressed in fractional units, `0 >= settlement_atto_amount < 1e18`
        uint256 settlementAmountAtto;
        /// @notice numeric code using ISO 4217
        uint16 settlementCurrency;
        /// @notice Hashes identifying consumption records batch (base32-encoded, unique per record)
        bytes32[] crHashes;
    }

    event Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp);
    event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);

    error AlreadyExists();
    error ConsumptionRecordAlreadyExists();
    error CRANotActive();
    error InvalidHash();
    error InvalidOwner();
    error EmptyBatch();
    error BatchSizeTooLarge();
    error InvalidSettlementCurrency();
    error InvalidAmount();
    error ArrayLengthMismatch();

    function submit(
        bytes32 cuHash,
        address owner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint128 settlementAmountBase,
        uint128 settlementAmountAtto,
        bytes32[] memory hashes
    ) external;

    function submitBatch(
        bytes32[] memory cuHashes,
        address[] memory owners,
        uint32[] memory worldwideDays,
        uint16[] memory settlementCurrencies,
        uint256[] memory settlementAmountsBase,
        uint256[] memory settlementAmountsAtto,
        bytes32[][] memory crHashesArray
    ) external;

    function isExists(bytes32 cuHash) external view returns (bool);

    function getConsumptionUnit(bytes32 cuHash) external view returns (ConsumptionUnitEntity memory);

    function setCRARegistry(address _craRegistry) external;

    function getCRARegistry() external view returns (address);

    function getConsumptionUnitsByOwner(address owner) external view returns (bytes32[] memory);
}
