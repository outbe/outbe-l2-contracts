// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IConsumptionRecord} from "../interfaces/IConsumptionRecord.sol";
import {ICRARegistry} from "../interfaces/ICRARegistry.sol";

/// @title ConsumptionRecord  
/// @notice Contract for storing consumption record hashes with metadata
/// @dev This contract allows active CRAs to submit consumption records with flexible metadata
/// @author Outbe Team
/// @custom:version 0.0.1
/// @custom:security-contact security@outbe.io
contract ConsumptionRecord is IConsumptionRecord {
    /// @notice Contract version
    string public constant VERSION = "0.0.1";
    
    /// @dev Mapping from record hash to record details
    mapping(bytes32 => CrRecord) public consumptionRecords;
    
    /// @dev Mapping from record hash to metadata key-value pairs
    mapping(bytes32 => mapping(string => string)) public crMetadata;
    
    /// @dev Mapping from record hash to array of metadata keys for enumeration
    mapping(bytes32 => string[]) public crMetadataKeys;

    /// @dev Reference to the CRA Registry contract
    ICRARegistry public craRegistry;
    
    /// @dev Contract owner who can update registry address
    address private owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert CRANotActive();
        _;
    }

    modifier onlyActiveCra() {
        if (!craRegistry.isCraActive(msg.sender)) revert CRANotActive();
        _;
    }

    modifier validCrHash(bytes32 crHash) {
        if (crHash == bytes32(0)) revert InvalidHash();
        _;
    }

    /// @notice Initialize the consumption record contract
    /// @dev Sets the CRA registry address and deployer as owner
    /// @param _craRegistry Address of the CRA Registry contract
    constructor(address _craRegistry) {
        craRegistry = ICRARegistry(_craRegistry);
        owner = msg.sender;
    }

    /// @inheritdoc IConsumptionRecord
    function submit(bytes32 crHash, string[] memory keys, string[] memory values)
        external
        onlyActiveCra
        validCrHash(crHash)
    {
        if (isExists(crHash)) revert AlreadyExists();
        if (keys.length != values.length) revert MetadataKeyValueMismatch();

        consumptionRecords[crHash] = CrRecord({submittedBy: msg.sender, submittedAt: block.timestamp});

        for (uint256 i = 0; i < keys.length; i++) {
            if (bytes(keys[i]).length == 0) revert EmptyMetadataKey();

            crMetadata[crHash][keys[i]] = values[i];
            crMetadataKeys[crHash].push(keys[i]);

            emit MetadataAdded(crHash, keys[i], values[i]);
        }

        emit Submitted(crHash, msg.sender, block.timestamp);
    }

    /// @inheritdoc IConsumptionRecord
    function isExists(bytes32 crHash) public view returns (bool) {
        return consumptionRecords[crHash].submittedBy != address(0);
    }

    /// @inheritdoc IConsumptionRecord
    function getDetails(bytes32 crHash) external view returns (CrRecord memory) {
        return consumptionRecords[crHash];
    }

    /// @inheritdoc IConsumptionRecord
    function getMetadata(bytes32 crHash, string memory key) external view returns (string memory) {
        return crMetadata[crHash][key];
    }

    /// @inheritdoc IConsumptionRecord
    function getMetadataKeys(bytes32 crHash) external view returns (string[] memory) {
        return crMetadataKeys[crHash];
    }

    /// @inheritdoc IConsumptionRecord
    function setCraRegistry(address _craRegistry) external onlyOwner {
        craRegistry = ICRARegistry(_craRegistry);
    }

    /// @inheritdoc IConsumptionRecord
    function getCraRegistry() external view returns (address) {
        return address(craRegistry);
    }

    /// @notice Get the current owner of the contract
    /// @return The address of the contract owner
    function getOwner() external view returns (address) {
        return owner;
    }
}
