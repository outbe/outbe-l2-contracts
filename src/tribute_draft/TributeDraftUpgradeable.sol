// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ITributeDraft} from "../interfaces/ITributeDraft.sol";
import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {ISoulBoundNFT} from "../interfaces/ISoulBoundNFT.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

/// @title TributeDraftUpgradeable
/// @notice Any user can mint a Tribute Draft by aggregating multiple Consumption Units
contract TributeDraftUpgradeable is
    ITributeDraft,
    ISoulBoundNFT,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC165Upgradeable
{
    string public constant VERSION = "1.0.0";

    IConsumptionUnit public consumptionUnit;

    // mapping from tribute draft id (hash) to entity
    mapping(bytes32 => TributeDraftEntity) public tributeDrafts;
    mapping(bytes32 => bool) public consumptionUnitHashes;

    /// @dev Total number of records tracked by this contract
    uint256 private _totalRecords;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _consumptionUnit) public initializer {
        require(_consumptionUnit != address(0), "CU addr zero");
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC165_init();
        _setConsumptionUnitAddress(_consumptionUnit);
        _transferOwnership(msg.sender);
        _totalRecords = 0;
    }

    function submit(bytes32[] calldata cuHashes) external returns (bytes32 tdId) {
        uint32 n = uint32(cuHashes.length);
        if (n == 0) revert EmptyArray();

        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (cuHashes[i] == cuHashes[j]) revert AlreadyExists();
            }
            // check it wasn't previously submitted
            if (consumptionUnitHashes[cuHashes[i]]) {
                revert AlreadyExists();
            }
            consumptionUnitHashes[cuHashes[i]] = true;
        }

        // fetch and validate
        IConsumptionUnit.ConsumptionUnitEntity memory first = consumptionUnit.getConsumptionUnit(cuHashes[0]);
        if (first.submittedBy == address(0)) revert NotFound(cuHashes[0]);
        if (msg.sender != first.owner) revert NotSameOwner(cuHashes[0]);

        address owner_ = first.owner;
        uint16 currency_ = first.settlementCurrency;
        uint32 worldwideDay_ = first.worldwideDay;
        uint64 baseAmt = first.settlementAmountBase;
        uint128 attoAmt = first.settlementAmountAtto;

        for (uint32 i = 1; i < n; i++) {
            IConsumptionUnit.ConsumptionUnitEntity memory rec = consumptionUnit.getConsumptionUnit(cuHashes[i]);
            if (rec.submittedBy == address(0)) revert NotFound(cuHashes[i]);
            if (rec.owner != owner_) revert NotSameOwner(cuHashes[i]);
            // compare currency codes by keccak hash of the encoded values
            if (keccak256(abi.encode(rec.settlementCurrency)) != keccak256(abi.encode(currency_))) {
                revert NotSettlementCurrencyCurrency();
            }

            if (keccak256(abi.encode(rec.worldwideDay)) != keccak256(abi.encode(worldwideDay_))) {
                revert NotSameWorldwideDay();
            }

            // aggregate amount: base + atto with carry (checked arithmetic)
            baseAmt += rec.settlementAmountBase;
            uint128 attoSum = attoAmt + rec.settlementAmountAtto;
            if (attoSum >= 1e18) {
                baseAmt += uint64(attoSum / 1e18);
                attoAmt = uint128(attoSum % 1e18);
            } else {
                attoAmt = attoSum;
            }
        }

        // generate tribute draft id as hash of provided CU hashes
        tdId = keccak256(abi.encode(owner_, worldwideDay_, cuHashes));

        tributeDrafts[tdId] = TributeDraftEntity({
            tributeDraftId: tdId,
            owner: owner_,
            settlementCurrency: currency_,
            worldwideDay: worldwideDay_,
            settlementAmountBase: baseAmt,
            settlementAmountAtto: attoAmt,
            cuHashes: cuHashes,
            submittedAt: block.timestamp
        });

        // Increment total supply for each new tribute draft
        _totalRecords += 1;

        emit Submitted(tdId, owner_, msg.sender, n, block.timestamp);
    }

    function getTributeDraft(bytes32 tdId) external view returns (TributeDraftEntity memory) {
        return tributeDrafts[tdId];
    }

    function getConsumptionUnitAddress() external view returns (address) {
        return address(consumptionUnit);
    }

    function setConsumptionUnitAddress(address _consumptionUnitAddress) external onlyOwner {
        _setConsumptionUnitAddress(_consumptionUnitAddress);
    }

    function _setConsumptionUnitAddress(address _consumptionUnitAddress) private {
        consumptionUnit = IConsumptionUnit(_consumptionUnitAddress);
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
}
