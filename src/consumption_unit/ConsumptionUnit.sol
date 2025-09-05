// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICRARegistry} from "../interfaces/ICRARegistry.sol";
import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";

/// @title ConsumptionUnit
/// @notice Contract for storing consumption unit records with settlement and nominal amounts
/// @dev Modeled after ConsumptionRecord with adapted CuRecord structure
contract ConsumptionUnit is IConsumptionUnit {
    string public constant VERSION = "0.0.1";
    uint256 public constant MAX_BATCH_SIZE = 100;

    mapping(bytes32 => CuRecord) public consumptionUnits;
    mapping(bytes32 => bool) public consumptionRecordHashes;
    mapping(address => bytes32[]) public ownerRecords;
    ICRARegistry public craRegistry;
    address private owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert CRANotActive();
        _;
    }

    modifier onlyActiveCra() {
        if (!craRegistry.isCraActive(msg.sender)) revert CRANotActive();
        _;
    }

    constructor(address _craRegistry, address _owner) {
        require(_craRegistry != address(0), "CRA Registry cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        craRegistry = ICRARegistry(_craRegistry);
        owner = _owner;
    }

    function _validateAmounts(uint64 baseAmt, uint128 attoAmt) internal pure {
        // baseAmt is uint64, already >= 0. attoAmt must be < 1e18
        if (attoAmt >= 1e18) revert InvalidAmount();
    }

    function _validateCurrency(string memory code) internal pure {
        // Must be non-empty; no strict ISO4217 enforcement on-chain
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
        return owner;
    }
}
