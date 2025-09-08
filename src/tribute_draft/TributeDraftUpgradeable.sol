// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ITributeDraft} from "../interfaces/ITributeDraft.sol";
import {IConsumptionUnit} from "../interfaces/IConsumptionUnit.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title TributeDraftUpgradeable
/// @notice Any user can mint a Tribute Draft by aggregating multiple Consumption Units
contract TributeDraftUpgradeable is ITributeDraft, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    string public constant VERSION = "1.0.0";

    IConsumptionUnit public consumptionUnit;

    // mapping from tribute draft id (hash) to entity
    mapping(bytes32 => TributeDraftEntity) public tributeDrafts;
    mapping(bytes32 => bool) public consumptionUnitHashes;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _consumptionUnit) public initializer {
        require(_consumptionUnit != address(0), "CU addr zero");
        __Ownable_init();
        __UUPSUpgradeable_init();
        consumptionUnit = IConsumptionUnit(_consumptionUnit);
        // owner set to deployer by default
        _transferOwnership(msg.sender);
    }

    function mint(bytes32[] calldata cuHashes) external returns (bytes32 tdId) {
        uint256 n = cuHashes.length;
        if (n == 0) revert EmptyArray();

        for (uint256 i = 0; i < n; i++) {
            // check it wasn't previously submitted
            if (consumptionUnitHashes[cuHashes[i]]) {
                revert DuplicateId();
            }
            consumptionUnitHashes[cuHashes[i]] = true;
        }

        // fetch and validate
        IConsumptionUnit.ConsumptionUnitEntity memory first = consumptionUnit.getRecord(cuHashes[0]);
        if (first.submittedBy == address(0)) revert NotFound(cuHashes[0]);
        if (msg.sender != first.owner) revert NotSameOwner();

        address owner_ = first.owner;
        string memory currency_ = first.settlementCurrency;
        uint64 baseAmt = first.settlementBaseAmount;
        uint128 attoAmt = first.settlementAttoAmount;

        for (uint256 i = 1; i < n; i++) {
            IConsumptionUnit.ConsumptionUnitEntity memory rec = consumptionUnit.getRecord(cuHashes[i]);
            if (rec.submittedBy == address(0)) revert NotFound(cuHashes[i]);
            if (rec.owner != owner_) revert NotSameOwner();
            // compare currency strings by keccak hash
            if (keccak256(bytes(rec.settlementCurrency)) != keccak256(bytes(currency_))) revert NotSameCurrency();

            // aggregate amount: base + atto with carry (checked arithmetic)
            baseAmt += rec.settlementBaseAmount;
            uint128 attoSum = attoAmt + rec.settlementAttoAmount;
            if (attoSum >= 1e18) {
                baseAmt += uint64(attoSum / 1e18);
                attoAmt = uint128(attoSum % 1e18);
            } else {
                attoAmt = attoSum;
            }
        }

        // generate tribute draft id as hash of provided CU hashes
        tdId = keccak256(abi.encode(cuHashes));
        if (tributeDrafts[tdId].submittedAt != 0) revert AlreadyExists(tdId);

        tributeDrafts[tdId] = TributeDraftEntity({
            owner: owner_,
            settlementCurrency: currency_,
            settlementBaseAmount: baseAmt,
            settlementAttoAmount: attoAmt,
            cuHashes: cuHashes,
            submittedAt: block.timestamp
        });

        emit Minted(tdId, owner_, msg.sender, n, block.timestamp);
    }

    function get(bytes32 tdId) external view returns (TributeDraftEntity memory) {
        return tributeDrafts[tdId];
    }

    function getConsumptionUnit() external view returns (address) {
        return address(consumptionUnit);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
