// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IConsumptionUnit} from "./IConsumptionUnit.sol";
import {ICRARegistry} from "../cra_registry/ICRARegistry.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title ConsumptionUnitUpgradeable
/// @notice Upgradeable contract for storing consumption unit records with settlement and nominal amounts
/// @dev Modeled after ConsumptionRecordUpgradeable with adapted CuRecord structure
contract ConsumptionUnitUpgradeable is IConsumptionUnit, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    string public constant VERSION = "1.0.0";
    uint256 public constant MAX_BATCH_SIZE = 100;

    mapping(bytes32 => CuRecord) public consumptionUnits;
    mapping(bytes32 => bool) public consumptionRecordHashes;
    mapping(address => bytes32[]) public ownerRecords;
    ICRARegistry public craRegistry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyActiveCra() {
        if (!craRegistry.isCraActive(msg.sender)) revert CRANotActive();
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

    function _validateAmounts(uint64 baseAmt, uint128 attoAmt) internal pure {
        if (attoAmt >= 1e18) revert InvalidAmount();
    }

    function _validateCurrency(string memory code) internal pure {
        if (bytes(code).length == 0) revert InvalidCurrency();
    }

    function _addRecord(
        bytes32 cuHash,
        address recordOwner,
        string memory settlementCurrency,
        uint64 settlementBaseAmount,
        uint128 settlementAttoAmount,
        uint64 nominalBaseQty,
        uint128 nominalAttoQty,
        string memory nominalCurrency,
        bytes32[] memory hashes,
        uint256 timestamp
    ) internal {
        if (cuHash == bytes32(0)) revert InvalidHash();
        if (recordOwner == address(0)) revert InvalidOwner();
        if (isExists(cuHash)) revert AlreadyExists();

        _validateCurrency(settlementCurrency);
        _validateCurrency(nominalCurrency);
        _validateAmounts(settlementBaseAmount, settlementAttoAmount);
        _validateAmounts(nominalBaseQty, nominalAttoQty);

        // check CR hashes uniqueness
        for (uint256 i = 0; i < hashes.length; i++) {
            if (consumptionRecordHashes[hashes[i]]) {
                revert CrAlreadyExists();
            }
            consumptionRecordHashes[hashes[i]] = true;
        }

        consumptionUnits[cuHash] = CuRecord({
            owner: recordOwner,
            submittedBy: msg.sender,
            settlementCurrency: settlementCurrency,
            settlementBaseAmount: settlementBaseAmount,
            settlementAttoAmount: settlementAttoAmount,
            nominalBaseQty: nominalBaseQty,
            nominalAttoQty: nominalAttoQty,
            nominalCurrency: nominalCurrency,
            hashes: hashes,
            submittedAt: timestamp
        });

        ownerRecords[recordOwner].push(cuHash);

        emit Submitted(cuHash, msg.sender, timestamp);
    }

    function submit(
        bytes32 cuHash,
        address recordOwner,
        string memory settlementCurrency,
        uint64 settlementBaseAmount,
        uint128 settlementAttoAmount,
        uint64 nominalBaseQty,
        uint128 nominalAttoQty,
        string memory nominalCurrency,
        bytes32[] memory hashes
    ) external onlyActiveCra {
        _addRecord(
            cuHash,
            recordOwner,
            settlementCurrency,
            settlementBaseAmount,
            settlementAttoAmount,
            nominalBaseQty,
            nominalAttoQty,
            nominalCurrency,
            hashes,
            block.timestamp
        );
    }

    function submitBatch(
        bytes32[] memory cuHashes,
        address[] memory owners,
        string[] memory settlementCurrencies,
        uint64[] memory settlementBaseAmounts,
        uint128[] memory settlementAttoAmounts,
        uint64[] memory nominalBaseQtys,
        uint128[] memory nominalAttoQtys,
        string[] memory nominalCurrencies,
        bytes32[][] memory hashesArray
    ) external onlyActiveCra {
        uint256 batchSize = cuHashes.length;
        if (batchSize == 0) revert EmptyBatch();
        if (batchSize > MAX_BATCH_SIZE) revert BatchSizeTooLarge();

        if (
            owners.length != batchSize || settlementCurrencies.length != batchSize
                || settlementBaseAmounts.length != batchSize || settlementAttoAmounts.length != batchSize
                || nominalBaseQtys.length != batchSize || nominalAttoQtys.length != batchSize
                || nominalCurrencies.length != batchSize || hashesArray.length != batchSize
        ) revert ArrayLengthMismatch();

        uint256 timestamp = block.timestamp;
        for (uint256 i = 0; i < batchSize; i++) {
            _addRecord(
                cuHashes[i],
                owners[i],
                settlementCurrencies[i],
                settlementBaseAmounts[i],
                settlementAttoAmounts[i],
                nominalBaseQtys[i],
                nominalAttoQtys[i],
                nominalCurrencies[i],
                hashesArray[i],
                timestamp
            );
        }

        emit BatchSubmitted(batchSize, msg.sender, timestamp);
    }

    function isExists(bytes32 cuHash) public view returns (bool) {
        return consumptionUnits[cuHash].submittedBy != address(0);
    }

    function getRecord(bytes32 cuHash) external view returns (CuRecord memory) {
        return consumptionUnits[cuHash];
    }

    function setCraRegistry(address _craRegistry) external onlyOwner {
        craRegistry = ICRARegistry(_craRegistry);
    }

    function getCraRegistry() external view returns (address) {
        return address(craRegistry);
    }

    function getRecordsByOwner(address _owner) external view returns (bytes32[] memory) {
        return ownerRecords[_owner];
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
