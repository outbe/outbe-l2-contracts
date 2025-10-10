// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";

/// @title ConsumptionUnitUpgradeable
/// @notice Upgradeable contract for storing consumption unit (CU) records with settlement currency and amounts
/// @dev Modeled after ConsumptionRecordUpgradeable with adapted ConsumptionUnitEntity structure
contract ConsumptionUnitUpgradeable is UUPSUpgradeable, CRAAware, IConsumptionUnit {
    /// @notice Contract version
    string public constant VERSION = "1.0.0";
    /// @notice Maximum number of CU records that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping CU hash to CU entity
    mapping(bytes32 => ConsumptionUnitEntity) public consumptionUnits;
    /// @dev Tracks uniqueness of linked consumption record (CR) hashes across all CU submissions
    mapping(bytes32 => bool) public consumptionRecordHashes;
    /// @dev Owner address to CU ids owned by the address
    mapping(address => bytes32[]) public ownerRecords;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the Consumption Unit contract
    /// @dev Sets CRA registry reference and transfers ownership to provided owner
    /// @param _craRegistry Address of CRARegistry contract (must not be zero)
    /// @param _owner Address to set as contract owner (must not be zero)
    function initialize(address _craRegistry, address _owner) public initializer {
        require(_craRegistry != address(0), "CRA Registry cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __UUPSUpgradeable_init();
        __CRAAware_init(_craRegistry);
        _transferOwnership(_owner);
    }

    function _validateAmounts(uint256 baseAmt, uint256 attoAmt) internal pure {
        if (baseAmt == 0 && attoAmt == 0) revert InvalidAmount();
        if (attoAmt >= 1e18) revert InvalidAmount();
    }

    function _validateCurrency(uint16 code) internal pure {
        if (code == 0) revert InvalidSettlementCurrency();
    }

    /// @dev Internal helper to validate and store a CU record and update indexes
    /// @param cuHash CU id/hash (must be non-zero and unique)
    /// @param recordOwner Owner address of the CU (must be non-zero)
    /// @param settlementCurrency ISO-4217 numeric currency code (must be non-zero)
    /// @param worldwideDay Worldwide day in ISO-8601 compact form, e.g. 20250923
    /// @param settlementBaseAmount Natural units amount (can be zero only if atto amount is non-zero)
    /// @param settlementAttoAmount Fractional units amount in 1e-18 units (must be < 1e18)
    /// @param crHashes Linked consumption record hashes (each must be unique globally)
    /// @param timestamp Submission timestamp to record
    function _addRecord(
        bytes32 cuHash,
        address recordOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint256 settlementBaseAmount,
        uint256 settlementAttoAmount,
        bytes32[] memory crHashes,
        uint256 timestamp
    ) internal {
        if (cuHash == bytes32(0)) revert InvalidHash();
        if (recordOwner == address(0)) revert InvalidOwner();
        if (isExists(cuHash)) revert AlreadyExists();

        _validateCurrency(settlementCurrency);
        _validateAmounts(settlementBaseAmount, settlementAttoAmount);

        // check CR hashes uniqueness
        for (uint256 i = 0; i < crHashes.length; i++) {
            if (consumptionRecordHashes[crHashes[i]]) {
                revert ConsumptionRecordAlreadyExists();
            }
            consumptionRecordHashes[crHashes[i]] = true;
        }
        // TODO add validation that such CR entity exists and owner is correct

        consumptionUnits[cuHash] = ConsumptionUnitEntity({
            consumptionUnitId: cuHash,
            owner: recordOwner,
            submittedBy: msg.sender,
            settlementCurrency: settlementCurrency,
            worldwideDay: worldwideDay,
            settlementAmountBase: settlementBaseAmount,
            settlementAmountAtto: settlementAttoAmount,
            crHashes: crHashes,
            submittedAt: timestamp
        });

        ownerRecords[recordOwner].push(cuHash);

        emit Submitted(cuHash, msg.sender, timestamp);
    }

    /// @inheritdoc IConsumptionUnit
    function submit(
        bytes32 cuHash,
        address recordOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint128 settlementBaseAmount,
        uint128 settlementAttoAmount,
        bytes32[] memory hashes
    ) external onlyActiveCRA {
        _addRecord(
            cuHash,
            recordOwner,
            settlementCurrency,
            worldwideDay,
            settlementBaseAmount,
            settlementAttoAmount,
            hashes,
            block.timestamp
        );
    }

    /// @inheritdoc IConsumptionUnit
    function submitBatch(
        bytes32[] memory cuHashes,
        address[] memory owners,
        uint32[] memory worldwideDays,
        uint16[] memory settlementCurrencies,
        uint256[] memory settlementAmountsBase,
        uint256[] memory settlementAmountsAtto,
        bytes32[][] memory crHashesArray
    ) external onlyActiveCRA {
        uint256 batchSize = cuHashes.length;
        if (batchSize == 0) revert EmptyBatch();
        if (batchSize > MAX_BATCH_SIZE) revert BatchSizeTooLarge();

        if (
            owners.length != batchSize || settlementCurrencies.length != batchSize || worldwideDays.length != batchSize
                || settlementAmountsBase.length != batchSize || settlementAmountsAtto.length != batchSize
                || crHashesArray.length != batchSize
        ) revert ArrayLengthMismatch();

        uint256 timestamp = block.timestamp;
        for (uint256 i = 0; i < batchSize; i++) {
            _addRecord(
                cuHashes[i],
                owners[i],
                settlementCurrencies[i],
                worldwideDays[i],
                settlementAmountsBase[i],
                settlementAmountsAtto[i],
                crHashesArray[i],
                timestamp
            );
        }

        emit BatchSubmitted(batchSize, msg.sender, timestamp);
    }

    function isExists(bytes32 cuHash) public view returns (bool) {
        return consumptionUnits[cuHash].submittedBy != address(0);
    }

    function getConsumptionUnit(bytes32 cuHash) external view returns (ConsumptionUnitEntity memory) {
        return consumptionUnits[cuHash];
    }

    function getConsumptionUnitsByOwner(address _owner) external view returns (bytes32[] memory) {
        return ownerRecords[_owner];
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
