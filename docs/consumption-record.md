# Consumption Record Contract

## Overview

The `ConsumptionRecord` contract is a smart contract designed to store consumption record hashes with associated metadata. It works in conjunction with a CRA Registry to ensure only active Consumption Reflection Agents (CRAs) can submit records.

## Contract Details

- **Version**: 0.0.1
- **License**: MIT
- **Solidity Version**: ^0.8.13
- **Location**: `src/consumption_record/ConsumptionRecord.sol`

## Architecture

The contract implements the `IConsumptionRecord` interface and maintains:

- A mapping of consumption record hashes to their submission details
- Key-value metadata storage for each record
- Integration with a CRA Registry for access control

## Core Data Structures

### CrRecord
```solidity
struct CrRecord {
    address submittedBy;  // Address of the CRA that submitted the record
    uint256 submittedAt;  // Timestamp of submission
}
```

## State Variables

- `consumptionRecords`: Maps record hashes to their submission details
- `crMetadata`: Two-level mapping for key-value metadata per record
- `crMetadataKeys`: Array of metadata keys for each record
- `craRegistry`: Reference to the CRA Registry contract
- `owner`: Contract owner address

## Access Control

### Modifiers

- `onlyOwner`: Restricts access to contract owner
- `onlyActiveCra`: Ensures caller is an active CRA in the registry
- `validCrHash`: Validates that the hash is not empty

## Core Functions

### submit()
```solidity
function submit(
    bytes32 crHash,
    string[] memory keys,
    string[] memory values
) external onlyActiveCra validCrHash(crHash)
```

Submits a new consumption record with metadata.

**Requirements:**
- Caller must be an active CRA
- Hash must be valid (non-zero)
- Record must not already exist
- Metadata keys and values arrays must have matching lengths
- Keys cannot be empty

**Events Emitted:**
- `Submitted(crHash, msg.sender, block.timestamp)`
- `MetadataAdded(crHash, key, value)` for each metadata pair

### Query Functions

- `isExists(bytes32 crHash)`: Check if a record exists
- `getDetails(bytes32 crHash)`: Get submission details
- `getMetadata(bytes32 crHash, string key)`: Get specific metadata value
- `getMetadataKeys(bytes32 crHash)`: Get all metadata keys for a record

### Administrative Functions

- `setCraRegistry(address)`: Update CRA Registry address (owner only)
- `getCraRegistry()`: Get current CRA Registry address
- `getOwner()`: Get contract owner address

## Events

```solidity
event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp);
event MetadataAdded(bytes32 indexed crHash, string key, string value);
```

## Custom Errors

- `AlreadyExists()`: Record hash already exists
- `CRANotActive()`: Caller is not an active CRA or not owner
- `InvalidHash()`: Hash is empty/invalid
- `MetadataKeyValueMismatch()`: Key and value arrays have different lengths
- `EmptyMetadataKey()`: Empty key provided in metadata

## Security Considerations

1. **Access Control**: Only active CRAs can submit records, verified through the CRA Registry
2. **Data Integrity**: Records are immutable once submitted - no update functionality
3. **Hash Validation**: Prevents submission of empty hashes
4. **Metadata Validation**: Ensures proper key-value pairing and non-empty keys
5. **Owner Controls**: Owner can update registry address but cannot modify existing records

## Usage Example

```solidity
// Deploy with CRA Registry address
ConsumptionRecord cr = new ConsumptionRecord(craRegistryAddress);

// Submit a record (as an active CRA)
string[] memory keys = new string[](2);
string[] memory values = new string[](2);
keys[0] = "source";
values[0] = "renewable";
keys[1] = "amount";
values[1] = "100";

cr.submit(recordHash, keys, values);

// Query the record
CrRecord memory record = cr.getDetails(recordHash);
string memory sourceValue = cr.getMetadata(recordHash, "source");
```

## Integration with CRA Registry

The contract depends on the CRA Registry to:
- Verify CRA active status before allowing submissions
- Maintain centralized CRA management
- Provide access control for the consumption record system

The registry address can be updated by the owner to allow for upgrades or migrations.