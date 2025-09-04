# Consumption Record Contract

## Overview

The `ConsumptionRecordUpgradeable` contract is an upgradeable smart contract designed to store consumption record hashes with associated metadata. It works in conjunction with a CRA Registry to ensure only active Consumption Reflection Agents (CRAs) can submit records, using the UUPS (Universal Upgradeable Proxy Standard) pattern.

## Contract Details

- **Version**: 1.0.0
- **License**: MIT
- **Solidity Version**: ^0.8.13
- **Location**: `src/consumption_record/ConsumptionRecordUpgradeable.sol`
- **Pattern**: UUPS Upgradeable Proxy
- **Deployment**: CREATE2 deterministic addresses

## Architecture

The contract implements the `IConsumptionRecord` interface and uses the UUPS upgradeable pattern:

```
User/Client → Proxy Contract → Implementation Contract
              (Fixed Address)   (Upgradeable Logic)
              (Stores State)
```

**Key Features:**
- Mapping of consumption record hashes to their submission details
- Key-value metadata storage for each record
- Integration with upgradeable CRA Registry for access control
- UUPS upgradeable pattern for seamless updates
- CREATE2 deterministic deployment addresses
- Initializer pattern instead of constructor

## Core Data Structures

### CrRecord
```solidity
struct CrRecord {
    address submittedBy;      // Address of the CRA that submitted the record
    uint256 submittedAt;      // Timestamp of submission
    address owner;            // Address of the owner of this consumption record
    string[] metadataKeys;    // Array of metadata keys
    string[] metadataValues;  // Array of metadata values (matches keys array)
}
```

## Constants

- `VERSION`: Contract version (1.0.0)
- `MAX_BATCH_SIZE`: Maximum number of records that can be submitted in a single batch (100)

## State Variables

- `consumptionRecords`: Maps record hashes to their complete submission details including metadata
- `ownerRecords`: Maps owner addresses to arrays of record hashes they own
- `craRegistry`: Reference to the upgradeable CRA Registry contract
- Inherited from `OwnableUpgradeable`: Owner functionality
- Inherited from `UUPSUpgradeable`: Upgrade authorization

## Access Control

### Modifiers

- `onlyOwner`: Restricts access to contract owner
- `onlyActiveCra`: Ensures caller is an active CRA in the registry
- `validOwner(address)`: Validates that the owner address is not zero address

## Core Functions

### Initialization

#### initialize()
```solidity
function initialize(address _craRegistry, address _owner) public initializer
```

Initializes the upgradeable contract (replaces constructor).

**Requirements:**
- Can only be called once (initializer modifier)
- CRA Registry cannot be zero address
- Owner cannot be zero address

**Effects:**
- Initializes OpenZeppelin upgradeable components
- Sets the CRA Registry reference
- Sets the contract owner

### Record Management

#### submit()
```solidity
function submit(
    bytes32 crHash,
    address owner,
    string[] memory keys,
    string[] memory values
) external onlyActiveCra
```

Submits a new consumption record with metadata and owner.

**Requirements:**
- Caller must be an active CRA
- Hash must be valid (non-zero)
- Owner must be valid (non-zero address)
- Record must not already exist
- Metadata keys and values arrays must have matching lengths
- Keys cannot be empty

**Events Emitted:**
- `Submitted(crHash, msg.sender, block.timestamp)`
- `MetadataAdded(crHash, key, value)` for each metadata pair

### submitBatch()
```solidity
function submitBatch(
    bytes32[] memory crHashes,
    address[] memory owners,
    string[][] memory keysArray,
    string[][] memory valuesArray
) external onlyActiveCra
```

Submits multiple consumption records in a single transaction for gas efficiency.

**Requirements:**
- Caller must be an active CRA
- Batch size must be between 1 and MAX_BATCH_SIZE (100)
- All array parameters must have matching lengths
- Each record must meet the same requirements as single submission
- All hashes must be unique within the batch

**Events Emitted:**
- `Submitted(crHash, msg.sender, timestamp)` for each record
- `MetadataAdded(crHash, key, value)` for each metadata pair in each record
- `BatchSubmitted(batchSize, msg.sender, timestamp)`

### Query Functions

- `isExists(bytes32 crHash)`: Check if a record exists
- `getRecord(bytes32 crHash)`: Get complete record data including metadata
- `getRecordsByOwner(address owner)`: Get all record hashes owned by a specific address

### Administrative Functions

- `setCraRegistry(address)`: Update CRA Registry address (owner only)
- `getCraRegistry()`: Get current CRA Registry address
- `getOwner()`: Get contract owner address (from OwnableUpgradeable)

### Upgrade Functions

#### upgradeTo()
```solidity
function upgradeTo(address newImplementation) external onlyOwner
```

Upgrades the contract to a new implementation.

**Requirements:**
- Only callable by owner
- New implementation must be a valid contract

#### upgradeToAndCall()
```solidity
function upgradeToAndCall(address newImplementation, bytes calldata data) external payable onlyOwner
```

Upgrades and calls a function on the new implementation in a single transaction.

#### VERSION()
```solidity
function VERSION() external pure returns (string memory)
```

Returns the current contract version ("1.0.0").

## Events

```solidity
event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp);
event MetadataAdded(bytes32 indexed crHash, string key, string value);
event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);
```

## Custom Errors

- `AlreadyExists()`: Record hash already exists
- `CRANotActive()`: Caller is not an active CRA or not owner
- `InvalidHash()`: Hash is empty/invalid
- `InvalidOwner()`: Owner address is zero address
- `MetadataKeyValueMismatch()`: Key and value arrays have different lengths
- `EmptyMetadataKey()`: Empty key provided in metadata
- `BatchSizeTooLarge()`: Batch size exceeds MAX_BATCH_SIZE (100)
- `EmptyBatch()`: Attempting to submit an empty batch

## Security Considerations

1. **Access Control**: Only active CRAs can submit records, verified through the CRA Registry
2. **Data Integrity**: Records are immutable once submitted - no update functionality
3. **Hash Validation**: Prevents submission of empty hashes
4. **Owner Validation**: Prevents assignment of records to zero address
5. **Metadata Validation**: Ensures proper key-value pairing and non-empty keys
6. **Batch Size Limits**: Prevents gas limit issues with MAX_BATCH_SIZE constraint
7. **Owner Controls**: Owner can update registry address but cannot modify existing records
8. **Gas Optimization**: Batch submissions reduce transaction costs for multiple records

## Deployment

### Using DeployUpgradeable Script

```bash
# Deploy with CREATE2 deterministic addresses
forge script script/DeployUpgradeable.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>

# Deploy with custom salt suffix
SALT_SUFFIX=mainnet_v1 forge script script/DeployUpgradeable.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>

# Predict addresses before deployment
forge script script/PredictAddresses.s.sol
```

### Using Cast for Interactions

```bash
# Submit a record (as active CRA)
cast send <PROXY_ADDRESS> "submit(bytes32,address,string[],string[])" <CR_HASH> <RECORD_OWNER> '["source","amount"]' '["renewable","100"]' --private-key <PRIVATE_KEY>

# Check if record exists
cast call <PROXY_ADDRESS> "isExists(bytes32)" <CR_HASH>

# Get complete record data
cast call <PROXY_ADDRESS> "getRecord(bytes32)" <CR_HASH>

# Get records by owner
cast call <PROXY_ADDRESS> "getRecordsByOwner(address)" <OWNER_ADDRESS>

# Get contract version
cast call <PROXY_ADDRESS> "VERSION()"
```

## Usage Examples

### Single Record Submission

```solidity
// Get the deployed proxy address (not the implementation!)
ConsumptionRecordUpgradeable cr = ConsumptionRecordUpgradeable(<PROXY_ADDRESS>);

// Submit a record (as an active CRA)
bytes32 recordHash = keccak256("consumption-data");
address recordOwner = 0x742d35Cc6634C0532925a3b8D09c2f76ec47a30B;

string[] memory keys = new string[](3);
string[] memory values = new string[](3);
keys[0] = "source";
values[0] = "renewable";
keys[1] = "amount"; 
values[1] = "100";
keys[2] = "unit";
values[2] = "kWh";

cr.submit(recordHash, recordOwner, keys, values);

// Query the complete record
CrRecord memory record = cr.getRecord(recordHash);
console.log("Owner:", record.owner);
console.log("Metadata count:", record.metadataKeys.length);

// Upgrade the contract (owner only)
cr.upgradeTo(newImplementationAddress);
```

### Batch Submission

```solidity
// Prepare batch data
bytes32[] memory hashes = new bytes32[](3);
address[] memory owners = new address[](3);
string[][] memory keysArray = new string[][](3);
string[][] memory valuesArray = new string[][](3);

// Record 1
hashes[0] = keccak256("record1");
owners[0] = recordOwner;
keysArray[0] = new string[](1);
keysArray[0][0] = "source";
valuesArray[0] = new string[](1);
valuesArray[0][0] = "solar";

// Record 2
hashes[1] = keccak256("record2");
owners[1] = recordOwner;
keysArray[1] = new string[](1);
keysArray[1][0] = "source";
valuesArray[1] = new string[](1);
valuesArray[1][0] = "wind";

// Record 3
hashes[2] = keccak256("record3");
owners[2] = recordOwner;
keysArray[2] = new string[](1);
keysArray[2][0] = "source";
valuesArray[2] = new string[](1);
valuesArray[2][0] = "hydro";

// Submit batch
cr.submitBatch(hashes, owners, keysArray, valuesArray);

// Query owner's records
bytes32[] memory ownerRecordHashes = cr.getRecordsByOwner(recordOwner);
console.log("Owner has", ownerRecordHashes.length, "records");
```

## Integration with CRA Registry

The contract depends on the CRARegistryUpgradeable to:
- Verify CRA active status before allowing submissions (both single and batch)
- Maintain centralized CRA management
- Provide access control for the consumption record system

**Important:** Both contracts use the same UUPS proxy pattern and CREATE2 deployment for consistent addresses across networks. The registry address can be updated by the owner to allow for upgrades or migrations.

## TypeScript Client Library

A comprehensive TypeScript client library is available in `examples/consumption-record.ts` that provides:

- **Single and batch submission methods**
- **Owner-based record queries** 
- **Complete record retrieval with metadata**
- **Event listening capabilities**
- **Error handling and validation**
- **Gas optimization for large datasets**
- **Utility functions for metadata management**

Key client features:
- `submit()` - Submit single record with owner and metadata
- `submitBatch()` - Submit multiple records efficiently  
- `getRecord()` - Get complete record data including metadata
- `getRecordsByOwner()` - Get all records for a specific owner
- `getCompleteRecordsByOwner()` - Get detailed records for an owner
- Event listeners for `Submitted`, `MetadataAdded`, and `BatchSubmitted` events

## Gas Optimization

The contract includes several gas optimization features:

1. **Batch Submissions**: Submit up to 100 records in a single transaction
2. **Embedded Metadata**: Metadata is stored directly in the record structure, eliminating separate mappings
3. **Owner Indexing**: Efficient querying of records by owner address
4. **Event Batching**: Single batch event reduces log overhead
5. **Validation Optimization**: Early validation prevents unnecessary computation

## Upgrade Considerations

When upgrading the contract:

1. **UUPS Proxy Pattern**: Upgrades preserve proxy address and all stored data
2. **Storage Layout**: Follow OpenZeppelin guidelines - only add new variables at the end
3. **CRA Registry Updates**: Owner can update the registry address seamlessly
4. **Data Persistence**: All existing records remain accessible after upgrades
5. **Backward Compatibility**: New features don't break existing integrations
6. **Version Tracking**: VERSION constant helps track deployed contract versions
7. **Upgrade Authorization**: Only owner can authorize upgrades via UUPS pattern

### Upgrade Process

```bash
# Deploy new implementation
forge script script/UpgradeImplementations.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>

# Or upgrade specific contract only
UPGRADE_CONSUMPTION_RECORD=true UPGRADE_CRA_REGISTRY=false forge script script/UpgradeImplementations.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>
```