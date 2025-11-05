// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {CRAAware} from "../utils/CRAAware.sol";
import {IConsumptionRecord} from "../interfaces/IConsumptionRecord.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SoulBoundTokenBase} from "../interfaces/SoulBoundTokenBase.sol";

/// @title ConsumptionRecordUpgradeable
/// @notice Upgradeable contract for storing consumption record hashes with metadata
/// @dev This contract allows active CRAs to submit consumption records with flexible metadata
/// @author Outbe Team
contract ConsumptionRecordUpgradeable is
    PausableUpgradeable,
    UUPSUpgradeable,
    CRAAware,
    SoulBoundTokenBase,
    IConsumptionRecord,
    MulticallUpgradeable
{
    /// @notice Contract version
    string public constant VERSION = "1.0.0";

    /// @notice Maximum number of records that can be submitted in a single batch
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @dev Mapping from record hash to record details
    mapping(uint256 => ConsumptionRecordEntity) private _data;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the consumption record contract
    /// @dev Sets the CRA registry address and specified owner
    /// @param _craRegistry Address of the CRA Registry contract
    /// @param _owner Address of the contract owner
    function initialize(address _craRegistry, address _owner) public initializer {
        require(_craRegistry != address(0), "CRA Registry cannot be zero address");
        require(_owner != address(0), "Owner cannot be zero address");
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __Base_initialize();
        __CRAAware_init(_craRegistry);
        __Multicall_init();
        _transferOwnership(_owner);
    }

    /// @inheritdoc SoulBoundTokenBase
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(SoulBoundTokenBase, IERC165Upgradeable)
        returns (bool)
    {
        return interfaceId == type(IConsumptionRecord).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc MulticallUpgradeable
    function multicall(bytes[] calldata data)
        external
        override(IConsumptionRecord, MulticallUpgradeable)
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = AddressUpgradeable.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }

    /// @inheritdoc IConsumptionRecord
    function submit(uint256 crId, address recordOwner, string[] memory keys, bytes32[] memory values)
        external
        onlyActiveCRA
        whenNotPaused
    {
        _submit(crId, recordOwner, keys, values, block.timestamp);
    }

    /// @inheritdoc IConsumptionRecord
    function getData(uint256 crId) public view override returns (ConsumptionRecordEntity memory) {
        return _data[crId];
    }

    /// @inheritdoc IConsumptionRecord
    function getConsumptionRecordsByOwner(address _owner, uint256 indexFrom, uint256 indexTo)
        public
        view
        returns (ConsumptionRecordEntity[] memory)
    {
        require(indexFrom <= indexTo, "Invalid request");
        uint256 n = indexTo - indexFrom + 1;
        require(n <= 50, "Request too big");

        ConsumptionRecordEntity[] memory result = new ConsumptionRecordEntity[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i + indexFrom);
            result[i] = getData(tokenId);
        }
        return result;
    }

    function _submit(
        uint256 crId,
        address tokenOwner,
        string[] memory keys,
        bytes32[] memory values,
        uint256 timestamp
    ) private {
        if (keys.length != values.length) revert InvalidMetadata("keys-values mismatch");
        for (uint256 i = 0; i < keys.length; i++) {
            if (bytes(keys[i]).length == 0) revert InvalidMetadata("empty key");
        }

        // mint the token
        _mint(_msgSender(), tokenOwner, crId);

        // Store the data
        _data[crId] = ConsumptionRecordEntity({
            crId: crId,
            submittedBy: _msgSender(),
            submittedAt: timestamp,
            owner: tokenOwner,
            metadataKeys: keys,
            metadataValues: values
        });
        emit Submitted(_msgSender(), tokenOwner, crId);
    }

    /// @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
    /// @param newImplementation Address of the new implementation
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
