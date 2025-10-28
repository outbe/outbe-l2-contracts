// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ITributeDraft} from "../interfaces/ITributeDraft.sol";
import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {SoulBoundTokenBase} from "../interfaces/SoulBoundTokenBase.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/// @title TributeDraftUpgradeable
/// @notice Any user can mint a Tribute Draft by aggregating multiple Consumption Units
contract TributeDraftUpgradeable is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ITributeDraft,
    SoulBoundTokenBase
{
    string public constant VERSION = "1.0.0";

    IConsumptionUnit public consumptionUnit;

    // mapping from tribute draft id (hash) to entity
    mapping(uint256  => TributeDraftEntity) private _data;
    mapping(uint256 => bool) public usedConsumptionUnitIds;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _consumptionUnit, address _owner) public initializer {
        require(_consumptionUnit != address(0), "CU addr zero");
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __Base_initialize();
        _setConsumptionUnitAddress(_consumptionUnit);
        _transferOwnership(_owner);
    }

    /// @inheritdoc SoulBoundTokenBase
    function supportsInterface(bytes4 interfaceId) public view virtual override (SoulBoundTokenBase, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(ITributeDraft).interfaceId || super.supportsInterface(interfaceId);
    }

    function submit(uint256[] calldata consumptionUnitIds) external returns (uint256 tokenId) {
        uint32 n = uint32(consumptionUnitIds.length);
        if (n == 0) revert EmptyArray();

        for (uint256 i = 0; i < n; i++) {
            // check it wasn't previously submitted
            if (usedConsumptionUnitIds[consumptionUnitIds[i]]) {
                revert AlreadyExists();
            }
            usedConsumptionUnitIds[consumptionUnitIds[i]] = true;
        }

        // fetch and validate
        IConsumptionUnit.ConsumptionUnitEntity memory first = consumptionUnit.getTokenData(consumptionUnitIds[0]);
        if (first.submittedBy == address(0)) revert NotFound(consumptionUnitIds[0]);
        if (msg.sender != first.owner) revert NotSameOwner(consumptionUnitIds[0]);

        address owner_ = first.owner;
        uint16 currency_ = first.settlementCurrency;
        uint32 worldwideDay_ = first.worldwideDay;
        uint64 baseAmt = first.settlementAmountBase;
        uint128 attoAmt = first.settlementAmountAtto;

        for (uint32 i = 1; i < n; i++) {
            IConsumptionUnit.ConsumptionUnitEntity memory rec = consumptionUnit.getTokenData(consumptionUnitIds[i]);
            if (rec.submittedBy == address(0)) revert NotFound(consumptionUnitIds[i]);
            if (rec.owner != owner_) revert NotSameOwner(consumptionUnitIds[i]);
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
                uint128 baseAdd = attoSum / 1e18;
                uint128 attoAdd = attoSum % 1e18;
                // casting to 'uint64' is safe because the amount wouldn't be so large value
                // forge-lint: disable-next-line(unsafe-typecast)
                baseAmt += uint64(baseAdd);
                attoAmt = attoAdd;
            } else {
                attoAmt = attoSum;
            }
        }

        // generate tribute draft id as hash of provided CU hashes
        tokenId = uint256 (keccak256(abi.encode(owner_, worldwideDay_, consumptionUnitIds)));

        _mint(address(0), owner_, tokenId);

        _data[tokenId] = TributeDraftEntity({
            owner: owner_,
            settlementCurrency: currency_,
            worldwideDay: worldwideDay_,
            settlementAmountBase: baseAmt,
            settlementAmountAtto: attoAmt,
            cuHashes: consumptionUnitIds,
            submittedAt: block.timestamp
        });
    }

    function getTokenData(uint256 tokenId) external view returns (TributeDraftEntity memory) {
        return _data[tokenId];
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
