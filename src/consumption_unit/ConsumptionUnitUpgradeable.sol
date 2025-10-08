// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {ICRARegistry} from "../interfaces/ICRARegistry.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title ConsumptionUnitUpgradeable
/// @notice Upgradeable contract for storing consumption unit records with settlement and nominal amounts
/// @dev Modeled after ConsumptionRecordUpgradeable with adapted CuRecord structure
contract ConsumptionUnitUpgradeable is IConsumptionUnit, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    string public constant VERSION = "1.0.0";
    uint256 public constant MAX_BATCH_SIZE = 100;

    mapping(bytes32 => ConsumptionUnitEntity) public consumptionUnits;
    mapping(bytes32 => bool) public consumptionRecordHashes;
    mapping(address => bytes32[]) public ownerRecords;
    ICRARegistry public craRegistry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyActiveCra() {
        if (!craRegistry.isCRAActive(msg.sender)) revert CRANotActive();
        _;
    }

    function initialize(address _craRegistry, address _owner) public initializer {
        require(_craRegistry != address(0), "CRA Registry cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __UUPSUpgradeable_init();
        craRegistry = ICRARegistry(_craRegistry);
        _transferOwnership(_owner);
    }

    function _validateAmounts(uint256 baseAmt, uint256 attoAmt) internal pure {
        if (baseAmt == 0 && attoAmt == 0) revert InvalidAmount();
        if (attoAmt >= 1e18) revert InvalidAmount();
    }

    function _validateCurrency(uint16 code) internal pure {
        if (code == 0) revert InvalidSettlementCurrency();
    }

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

    function submit(
        bytes32 cuHash,
        address recordOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint128 settlementBaseAmount,
        uint128 settlementAttoAmount,
        bytes32[] memory hashes
    ) external onlyActiveCra {
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

    function submitBatch(
        bytes32[] memory cuHashes,
        address[] memory owners,
        uint32[] memory worldwideDays,
        uint16[] memory settlementCurrencies,
        uint256[] memory settlementAmountsBase,
        uint256[] memory settlementAmountsAtto,
        bytes32[][] memory crHashesArray
    ) external onlyActiveCra {
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

    function setCRARegistry(address _craRegistry) external onlyOwner {
        craRegistry = ICRARegistry(_craRegistry);
    }

    function getCRARegistry() external view returns (address) {
        return address(craRegistry);
    }

    function getConsumptionUnitsByOwner(address _owner) external view returns (bytes32[] memory) {
        return ownerRecords[_owner];
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
