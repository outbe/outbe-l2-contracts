// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {ISoulBoundNFT} from "../interfaces/ISoulBoundNFT.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";
import {IConsumptionRecord} from "../interfaces/IConsumptionRecord.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/// @title ConsumptionUnitUpgradeable
/// @notice Upgradeable contract for storing consumption unit (CU) records with settlement currency and amounts
/// @dev Modeled after ConsumptionRecordUpgradeable with adapted ConsumptionUnitEntity structure
contract ConsumptionUnitUpgradeable is
    PausableUpgradeable,
    UUPSUpgradeable,
    CRAAware,
    IConsumptionUnit,
    ISoulBoundNFT,
    ERC165Upgradeable,
    MulticallUpgradeable
{
    /// @notice Reference to the Consumption Record contract
    IConsumptionRecord public consumptionRecord;
    /// @notice Contract version
    string public constant VERSION = "1.0.0";
    /// @notice Maximum number of CU records that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping CU hash to CU entity
    mapping(bytes32 => ConsumptionUnitEntity) public consumptionUnits;
    /// @dev Tracks uniqueness of linked consumption record (CR) hashes across all CU submissions
    mapping(bytes32 => bool) public usedConsumptionRecordHashes;
    /// @dev Owner address to CU ids owned by the address
    mapping(address => bytes32[]) public ownerRecords;

    /// @dev Total number of records tracked by this contract
    uint256 private _totalRecords;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the Consumption Unit contract
    /// @dev Sets CRA registry reference and transfers ownership to provided owner
    /// @param _craRegistry Address of CRARegistry contract (must not be zero)
    /// @param _owner Address to set as contract owner (must not be zero)
    function initialize(address _craRegistry, address _owner, address _consumptionRecord) public initializer {
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __ERC165_init();
        __CRAAware_init(_craRegistry);
        __Multicall_init();
        _transferOwnership(_owner);
        _totalRecords = 0;
        _setConsumptionRecordAddress(_consumptionRecord);
    }

    function _validateAmounts(uint64 baseAmt, uint128 attoAmt) internal pure {
        if (baseAmt == 0 && attoAmt == 0) revert InvalidAmount();
        if (attoAmt >= 1e18) revert InvalidAmount();
    }

    function _validateCurrency(uint16 code) internal pure {
        // TODO add supported codes
        if (code == 0) revert InvalidSettlementCurrency();
    }

    /// @dev Internal helper to validate and store a CU record and update indexes
    /// @param cuHash CU id/hash (must be non-zero and unique)
    /// @param recordOwner Owner address of the CU (must be non-zero)
    /// @param settlementCurrency ISO-4217 numeric currency code (must be non-zero)
    /// @param worldwideDay Worldwide day in ISO-8601 compact form, e.g. 20250923
    /// @param settlementAmountBase Natural units amount (can be zero only if atto amount is non-zero)
    /// @param settlementAmountAtto Fractional units amount in 1e-18 units (must be < 1e18)
    /// @param crHashes Linked consumption record hashes (each must be unique globally)
    /// @param amendmentHashes Linked consumption record amendment hashes (each must be unique globally)
    /// @param timestamp Submission timestamp to record
    function _addRecord(
        bytes32 cuHash,
        address recordOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        bytes32[] memory crHashes,
        bytes32[] memory amendmentHashes,
        uint256 timestamp
    ) private {
        if (cuHash == bytes32(0)) revert InvalidHash();
        if (recordOwner == address(0)) revert InvalidOwner();
        if (isExists(cuHash)) revert AlreadyExists();

        _validateCurrency(settlementCurrency);
        _validateAmounts(settlementAmountBase, settlementAmountAtto);

        _validateHashes(crHashes);
        if (amendmentHashes.length > 0) {
            _validateHashes(amendmentHashes);
        }

        consumptionUnits[cuHash] = ConsumptionUnitEntity({
            consumptionUnitId: cuHash,
            owner: recordOwner,
            submittedBy: msg.sender,
            settlementCurrency: settlementCurrency,
            worldwideDay: worldwideDay,
            settlementAmountBase: settlementAmountBase,
            settlementAmountAtto: settlementAmountAtto,
            crHashes: crHashes,
            amendmentCrHashes: amendmentHashes,
            submittedAt: timestamp
        });

        ownerRecords[recordOwner].push(cuHash);

        // Increment total supply for each new CU record
        _totalRecords += 1;

        emit Submitted(cuHash, msg.sender, timestamp);
    }

    /// @dev check hashes uniqueness and existence in CR contract
    function _validateHashes(bytes32[] memory _hashes) private {
        // TODO add limitation for hashes size
        uint256 n = _hashes.length;
        if (n == 0 || n > 100) revert InvalidConsumptionRecords();
        for (uint256 i = 0; i < n; i++) {
            bytes32 _hash = _hashes[i];
            // verify CR exists in ConsumptionRecord contract
            if (!consumptionRecord.isExists(_hash)) revert InvalidConsumptionRecords();

            if (usedConsumptionRecordHashes[_hash]) {
                revert ConsumptionRecordAlreadyExists();
            }
            usedConsumptionRecordHashes[_hash] = true;
        }
    }

    /// @inheritdoc IConsumptionUnit
    function submit(
        bytes32 cuHash,
        address recordOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        bytes32[] memory hashes,
        bytes32[] memory amendmentHashes
    ) external onlyActiveCRA whenNotPaused {
        _addRecord(
            cuHash,
            recordOwner,
            settlementCurrency,
            worldwideDay,
            settlementAmountBase,
            settlementAmountAtto,
            hashes,
            amendmentHashes,
            block.timestamp
        );
    }

    /// @notice Multicall entry point allowing multiple submits in a single transaction
    /// @dev Restricted to active CRAs and when not paused. Applies batch size limits consistent with submitBatch.
    function multicall(bytes[] calldata data)
        external
        override
        onlyActiveCRA
        whenNotPaused
        returns (bytes[] memory results)
    {
        uint256 n = data.length;
        if (n == 0) revert EmptyBatch();
        if (n > MAX_BATCH_SIZE) revert BatchSizeTooLarge();
        results = new bytes[](n);
        for (uint256 i = 0; i < n; i++) {
            if (bytes4(data[i]) != this.submit.selector) revert InvalidCall();
            results[i] = AddressUpgradeable.functionDelegateCall(address(this), data[i]);
        }
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

    function getConsumptionRecordAddress() external view returns (address) {
        return address(consumptionRecord);
    }

    function setConsumptionRecordAddress(address _consumptionRecord) external onlyOwner {
        _setConsumptionRecordAddress(_consumptionRecord);
    }

    function _setConsumptionRecordAddress(address _consumptionRecord) private {
        require(_consumptionRecord != address(0), "CR addr zero");
        consumptionRecord = IConsumptionRecord(_consumptionRecord);
    }

    /// @inheritdoc ISoulBoundNFT
    function totalSupply() external view returns (uint256) {
        return _totalRecords;
    }

    /// @inheritdoc ERC165Upgradeable
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
        // TODO add supported interfaces
        //      interfaceId == 0x780e9d63 // ERC721Enumerable
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Pause contract actions
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause contract actions
    function unpause() external onlyOwner {
        _unpause();
    }
}
