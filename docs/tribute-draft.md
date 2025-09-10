# TributeDraftUpgradeable Contract

## Overview

The **TributeDraftUpgradeable** contract enables users to mint tradeable tokens by aggregating multiple Consumption Units. It serves as the final layer in the Outbe ecosystem, creating tokenized representations of energy consumption that can be transferred, traded, or used for various applications.

## Architecture

### Data Structure

The core data structure is `TributeDraftEntity`:

```solidity
struct TributeDraftEntity {
    address owner;                   // Owner of all aggregated consumption units
    string settlementCurrency;      // Currency shared across all consumption units (ISO 4217)
    string worldwideDay;            // Day shared across all consumption units (ISO 8601)
    uint64 settlementBaseAmount;    // Aggregated settlement amount (natural units)
    uint128 settlementAttoAmount;   // Aggregated settlement amount (fractional units)
    bytes32[] cuHashes;             // Source consumption unit hashes
    uint256 submittedAt;            // Timestamp when tribute draft was minted
}
```

### Key Features

- **User-Mintable**: Any user can mint tribute drafts from their consumption units
- **Aggregation Validation**: Ensures all consumption units meet aggregation rules
- **Automatic Summation**: Calculates total settlement amounts with overflow handling
- **Unique Identification**: Tribute draft IDs based on consumption unit hash combinations
- **Double-Spending Prevention**: Each consumption unit can only be used once

## Core Functions

### Minting Functions

#### `mint(bytes32[] cuHashes)`
Mints a tribute draft by aggregating multiple consumption units.

**Access**: Any user (as owner of the consumption units)

**Parameters**:
- `bytes32[] cuHashes`: Array of consumption unit hashes to aggregate

**Returns**:
- `bytes32 tdId`: Unique tribute draft identifier

**Aggregation Rules**:
1. **Same Owner**: All consumption units must be owned by the caller
2. **Same Currency**: All consumption units must have identical settlement currency
3. **Same Day**: All consumption units must have identical worldwide day
4. **Amount Aggregation**: Settlement amounts are automatically summed with overflow handling
5. **Uniqueness**: Each consumption unit can only be used once across all tribute drafts

**Validation Process**:
1. Validates input array is not empty
2. Checks for duplicate consumption unit hashes in input
3. Verifies each consumption unit exists and hasn't been used
4. Confirms caller owns all consumption units
5. Validates currency and day consistency
6. Performs amount aggregation with carry handling

### Query Functions

#### `get(bytes32 tdId)`
Returns complete tribute draft details.

**Parameters**:
- `bytes32 tdId`: Tribute draft identifier

**Returns**:
- `TributeDraftEntity`: Complete tribute draft data

#### `getConsumptionUnit()`
Returns the address of the linked ConsumptionUnit contract.

## Events

### `Minted`
Emitted when a tribute draft is successfully minted.
```solidity
event Minted(
    bytes32 indexed tdId,
    address indexed owner,
    address indexed submittedBy,
    uint256 cuCount,
    uint256 timestamp
);
```

## Error Handling

### Custom Errors

- `EmptyArray()`: Empty consumption unit array provided
- `DuplicateId()`: Duplicate consumption unit hash in input or hash already used
- `NotFound(bytes32)`: Consumption unit not found
- `NotSameOwner()`: Consumption units have different owners or caller doesn't own them
- `NotSameCurrency()`: Consumption units have different settlement currencies
- `NotSameDay()`: Consumption units have different worldwide days

## Aggregation Algorithm

### Amount Summation
The contract performs precise aggregation of settlement amounts using base and atto components:

```solidity
// Aggregate amounts with carry handling
totalBase += cu.settlementBaseAmount;
totalAtto += cu.settlementAttoAmount;

// Handle atto overflow (carry to base)
if (totalAtto >= 1e18) {
    totalBase += totalAtto / 1e18;
    totalAtto = totalAtto % 1e18;
}
```

### Tribute Draft ID Generation
Tribute draft IDs are deterministically generated from the input consumption unit hashes:

```solidity
bytes32 tdId = keccak256(abi.encode(cuHashes));
```

This ensures that the same set of consumption units always produces the same tribute draft ID.

## Integration Patterns

### With Consumption Units
- Validates consumption unit existence and ownership
- Enforces aggregation rules across consumption units
- Tracks consumption unit usage to prevent double-spending
- Aggregates settlement amounts from multiple units

### With User Wallets
- Enables peer-to-peer transfer of tokenized consumption
- Supports integration with DEX protocols
- Allows fractional ownership through amount precision
- Facilitates energy credit trading

### With External Systems
- Provides standardized tokenization interface
- Supports integration with carbon credit systems
- Enables automated settlement and clearing
- Facilitates regulatory reporting and compliance

## Deployment Configuration

### Constructor Parameters
- None (uses initializer pattern)

### Initialization Parameters
- `address _consumptionUnit`: ConsumptionUnit contract address

### Required Dependencies
- ConsumptionUnit contract must be deployed and operational
- OpenZeppelin UUPS proxy setup

## Usage Examples

### Basic Minting
```solidity
// Mint tribute draft from consumption units
bytes32[] memory cuHashes = new bytes32[](3);
cuHashes[0] = 0x1111...;
cuHashes[1] = 0x2222...;
cuHashes[2] = 0x3333...;

bytes32 tributeDraftId = tributeDraft.mint(cuHashes);
```

### Query Operations
```solidity
// Get tribute draft details
TributeDraftEntity memory draft = tributeDraft.get(tributeDraftId);

// Check aggregated amounts
uint256 totalAmount = draft.settlementBaseAmount;
uint256 fractionalAmount = draft.settlementAttoAmount;

// Get source consumption units
bytes32[] memory sourceUnits = draft.cuHashes;
```

### Predictive Operations
```solidity
// Predict tribute draft ID before minting
bytes32 predictedId = keccak256(abi.encode(cuHashes));

// Verify prediction matches actual ID after minting
require(predictedId == actualTributeDraftId, "ID mismatch");
```

## Security Considerations

1. **Ownership Verification**: Only consumption unit owners can include them in tribute drafts
2. **Double-Spending Prevention**: Each consumption unit can only be used once
3. **Aggregation Validation**: Strict validation of currency and day consistency
4. **Input Validation**: Comprehensive validation of consumption unit hashes
5. **Overflow Protection**: Safe arithmetic for amount aggregation
6. **Access Control**: No special privileges required for minting

## Advanced Features

### Predictable IDs
Tribute draft IDs are deterministically generated, allowing:
- Pre-computation of tribute draft addresses
- Integration with external systems before minting
- Verification of tribute draft authenticity
- Support for conditional minting logic

### Flexible Aggregation
The contract supports flexible aggregation scenarios:
- Single consumption unit tribute drafts
- Multi-unit aggregation for larger amounts
- Mixed nominal quantities (aggregated by settlement currency)
- Cross-period aggregation (same day requirement ensures settlement consistency)

## Gas Optimization

- Efficient batch validation of consumption units
- Single external call per consumption unit for validation
- Optimized storage layout for tribute draft data
- Event emission for efficient off-chain indexing

## Monitoring and Analytics

### Key Metrics
- Total tribute drafts minted
- Average consumption units per tribute draft
- Settlement amount distribution by currency
- Minting activity by user
- Consumption unit utilization rates

### Event Indexing
- Index by tribute draft ID
- Index by owner address
- Index by minting timestamp
- Index by consumption unit count
- Index by settlement currency

## Error Scenarios and Recovery

### Common Error Cases
1. **Mismatched Currencies**: Different settlement currencies across consumption units
2. **Mismatched Days**: Different worldwide days across consumption units
3. **Already Used Units**: Attempting to use consumption units already in other tribute drafts
4. **Ownership Issues**: Attempting to use consumption units owned by other addresses

### Recovery Strategies
1. **Filter Compatible Units**: Query and filter consumption units by currency and day
2. **Check Usage Status**: Verify consumption units haven't been used before minting
3. **Validate Ownership**: Confirm ownership of all consumption units before attempting mint
4. **Batch Size Optimization**: Balance gas costs with minting efficiency

## Best Practices

1. **Pre-Validation**: Check aggregation compatibility before minting
2. **Gas Estimation**: Estimate gas costs for large consumption unit arrays
3. **Event Monitoring**: Set up listeners for minting events
4. **Error Handling**: Implement robust error handling for minting failures
5. **Amount Precision**: Handle base and atto amounts correctly in client applications
6. **ID Prediction**: Use predictable ID generation for integration planning

## Integration Examples

### DeFi Integration
```solidity
// Use tribute drafts as collateral
function depositTributeDraft(bytes32 tdId, uint256 amount) external {
    TributeDraftEntity memory draft = tributeDraft.get(tdId);
    require(draft.owner == msg.sender, "Not owner");
    // ... collateral logic
}
```

### Trading Integration
```solidity
// Create marketplace listing
function listTributeDraft(bytes32 tdId, uint256 price) external {
    TributeDraftEntity memory draft = tributeDraft.get(tdId);
    require(draft.owner == msg.sender, "Not owner");
    // ... marketplace logic
}
```

### Carbon Credit Integration
```solidity
// Convert to carbon credits
function convertToCarbon(bytes32 tdId) external {
    TributeDraftEntity memory draft = tributeDraft.get(tdId);
    uint256 carbonAmount = calculateCarbonCredits(draft);
    // ... carbon credit minting logic
}
```