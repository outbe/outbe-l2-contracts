// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";
import {IConsumptionRecord} from "../interfaces/IConsumptionRecord.sol";
import {IConsumptionRecordAmendment} from "../interfaces/IConsumptionRecordAmendment.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {SoulBoundTokenBase} from "../interfaces/SoulBoundTokenBase.sol";

/// @title ConsumptionUnitUpgradeable
/// @notice Upgradeable contract for storing consumption unit (CU) records with settlement currency and amounts
/// @dev Modeled after ConsumptionRecordUpgradeable with adapted ConsumptionUnitEntity structure
contract ConsumptionUnitUpgradeable is
    PausableUpgradeable,
    UUPSUpgradeable,
    CRAAware,
    SoulBoundTokenBase,
    IConsumptionUnit,
    MulticallUpgradeable
{
    /// @notice Reference to the Consumption Record contract
    IConsumptionRecord public consumptionRecord;
    /// @notice Reference to the Consumption Record Amendment contract
    IConsumptionRecordAmendment public consumptionRecordAmendment;
    /// @notice Contract version
    string public constant VERSION = "1.0.0";
    /// @notice Maximum number of tokens that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping CU hash to CU entity
    mapping(uint256 => ConsumptionUnitEntity) private _data;
    /// @dev Tracks uniqueness of linked consumption record (CR) hashes across all CU submissions
    mapping(uint256 => bool) public usedConsumptionRecordIds;
    /// @dev Tracks uniqueness of linked consumption record amendment hashes across all CU submissions
    mapping(uint256 => bool) public usedConsumptionRecordAmendmentIds;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the Consumption Unit contract
    /// @dev Sets CRA registry reference and transfers ownership to provided owner
    /// @param _craRegistry Address of CRARegistry contract (must not be zero)
    /// @param _owner Address to set as contract owner (must not be zero)
    /// @param _consumptionRecord Address of ConsumptionRecord contract (must not be zero)
    /// @param _consumptionRecordAmendment Address of ConsumptionRecordAmendment contract (must not be zero)
    function initialize(
        address _craRegistry,
        address _owner,
        address _consumptionRecord,
        address _consumptionRecordAmendment
    ) public initializer {
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __Base_initialize();
        __CRAAware_init(_craRegistry);
        __Multicall_init();
        _transferOwnership(_owner);
        _setConsumptionRecordAddress(_consumptionRecord);
        _setConsumptionRecordAmendmentAddress(_consumptionRecordAmendment);
    }

    /// @inheritdoc SoulBoundTokenBase
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SoulBoundTokenBase, IERC165Upgradeable)
        returns (bool)
    {
        return interfaceId == type(IConsumptionUnit).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc MulticallUpgradeable
    function multicall(bytes[] calldata data)
        external
        override(IConsumptionUnit, MulticallUpgradeable)
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = AddressUpgradeable.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }

    function _validateAmounts(uint64 baseAmt, uint128 attoAmt) internal pure {
        if (baseAmt == 0 && attoAmt == 0) revert InvalidAmount();
        if (attoAmt >= 1e18) revert InvalidAmount();
    }

    function _validateCurrency(uint16 code) internal pure {
        // TODO add supported codes
        if (code == 0) revert InvalidSettlementCurrency();
    }

    function _submit(
        uint256 cuId,
        address tokenOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        uint256[] memory crHashes,
        uint256[] memory amendmentCrHashes,
        uint256 timestamp
    ) private {
        _validateCurrency(settlementCurrency);
        _validateAmounts(settlementAmountBase, settlementAmountAtto);

        _validateHashes(crHashes);
        _validateAmendmentHashes(amendmentCrHashes);

        _mint(_msgSender(), tokenOwner, cuId);

        _data[cuId] = ConsumptionUnitEntity({
            cuId: cuId,
            owner: tokenOwner,
            submittedBy: msg.sender,
            settlementCurrency: settlementCurrency,
            worldwideDay: worldwideDay,
            settlementAmountBase: settlementAmountBase,
            settlementAmountAtto: settlementAmountAtto,
            crHashes: crHashes,
            amendmentCrHashes: amendmentCrHashes,
            submittedAt: timestamp
        });
        emit Submitted(
            _msgSender(), tokenOwner, cuId, worldwideDay, settlementAmountBase, settlementAmountAtto, settlementCurrency
        );
    }

    /// @dev check hashes uniqueness and existence in CR contract
    function _validateHashes(uint256[] memory _hashes) private {
        // TODO add limitation for hashes size
        uint256 n = _hashes.length;
        if (n == 0 || n > 100) revert InvalidConsumptionRecords();
        for (uint256 i = 0; i < n; i++) {
            uint256 _hash = _hashes[i];
            // verify CR exists in ConsumptionRecord contract
            if (!consumptionRecord.exists(_hash)) revert InvalidConsumptionRecords();

            if (usedConsumptionRecordIds[_hash]) {
                revert ConsumptionRecordAlreadyExists();
            }
            usedConsumptionRecordIds[_hash] = true;
        }
    }

    /// @dev check amendment hashes uniqueness and existence in CR Amendment contract
    function _validateAmendmentHashes(uint256[] memory _hashes) private {
        uint256 n = _hashes.length;
        if (n > 100) revert InvalidConsumptionRecords();
        for (uint256 i = 0; i < n; i++) {
            uint256 _hash = _hashes[i];
            // verify CR Amendment exists in ConsumptionRecordAmendment contract
            if (!consumptionRecordAmendment.exists(_hash)) revert InvalidConsumptionRecords();

            if (usedConsumptionRecordAmendmentIds[_hash]) {
                revert ConsumptionRecordAlreadyExists();
            }
            usedConsumptionRecordAmendmentIds[_hash] = true;
        }
    }

    /// @inheritdoc IConsumptionUnit
    function submit(
        uint256 cuId,
        address tokenOwner,
        uint16 settlementCurrency,
        uint32 worldwideDay,
        uint64 settlementAmountBase,
        uint128 settlementAmountAtto,
        uint256[] memory crHashes,
        uint256[] memory amendmentCrHashes
    ) external onlyActiveCRA whenNotPaused {
        _submit(
            cuId,
            tokenOwner,
            settlementCurrency,
            worldwideDay,
            settlementAmountBase,
            settlementAmountAtto,
            crHashes,
            amendmentCrHashes,
            block.timestamp
        );
    }

    /// @inheritdoc IConsumptionUnit
    function getData(uint256 cuId) public view returns (ConsumptionUnitEntity memory) {
        return _data[cuId];
    }

    /// @inheritdoc IConsumptionUnit
    function getConsumptionUnitsByOwner(address _owner, uint256 indexFrom, uint256 indexTo)
        public
        view
        returns (ConsumptionUnitEntity[] memory)
    {
        require(indexFrom <= indexTo, "Invalid request");
        uint256 n = indexTo - indexFrom + 1;
        require(n <= 50, "Request too big");

        ConsumptionUnitEntity[] memory result = new ConsumptionUnitEntity[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i + indexFrom);
            result[i] = getData(tokenId);
        }
        return result;
    }

    function getConsumptionRecordAddress() external view returns (address) {
        return address(consumptionRecord);
    }

    function getConsumptionRecordAmendmentAddress() external view returns (address) {
        return address(consumptionRecordAmendment);
    }

    function setConsumptionRecordAddress(address _consumptionRecord) external onlyOwner {
        _setConsumptionRecordAddress(_consumptionRecord);
    }

    function setConsumptionRecordAmendmentAddress(address _consumptionRecordAmendment) external onlyOwner {
        _setConsumptionRecordAmendmentAddress(_consumptionRecordAmendment);
    }

    function _setConsumptionRecordAddress(address _consumptionRecord) private {
        require(_consumptionRecord != address(0), "CR addr zero");
        consumptionRecord = IConsumptionRecord(_consumptionRecord);
    }

    function _setConsumptionRecordAmendmentAddress(address _consumptionRecordAmendment) private {
        require(_consumptionRecordAmendment != address(0), "CRA addr zero");
        consumptionRecordAmendment = IConsumptionRecordAmendment(_consumptionRecordAmendment);
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
