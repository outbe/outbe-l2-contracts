# ConsumptionUnitUpgradeable Contract

## Overview

The **ConsumptionUnitUpgradeable** contract aggregates consumption records into settlement units with currency amounts and nominal quantities. It serves as an intermediate layer between raw consumption records and tradeable tribute drafts, providing structured settlement data for energy consumption.

## Architecture

### Data Structure

The core data structure is `ConsumptionUnitEntity`:

```solidity
struct ConsumptionUnitEntity {
    address owner;                    // Owner of the consumption unit
    address submittedBy;              // CRA that submitted the unit
    string settlementCurrency;       // ISO 4217 currency code (e.g., "USD")
    string worldwideDay;             // ISO 8601 date string (e.g., "2024-01-15")
    uint64 settlementBaseAmount;     // Natural units (e.g., whole dollars)
    uint128 settlementAttoAmount;    // Fractional units (must be < 1e18)
    uint64 nominalBaseQty;           // Natural quantity units
    uint128 nominalAttoQty;          // Fractional quantity units (must be < 1e18)
    string nominalCurrency;          // Unit of measurement (e.g., "kWh")
    bytes32[] hashes;                // Referenced consumption record hashes
    uint256 submittedAt;             // Timestamp of submission
}
```

### Key Features

- **Settlement Amounts**: 18-decimal precision using base + atto components
- **Nominal Quantities**: Physical unit tracking (kWh, MWh, etc.)
- **Worldwide Day Grouping**: Settlement periods for aggregation
- **Consumption Record Traceability**: Links to source consumption records
- **CRA Access Control**: Only active CRAs can submit consumption units
- **Hash Uniqueness**: Prevents double-spending of consumption records

## Core Functions

### Submit Functions

#### `submit()`
Submits a single consumption unit with all required parameters.

**Access**: Only active CRAs (verified via CRA Registry)

**Parameters**:
- `bytes32 cuHash`: Unique identifier for the consumption unit
- `address recordOwner`: Owner of the consumption unit
- `string settlementCurrency`: ISO 4217 currency code
- `string worldwideDay`: ISO 8601 date string
- `uint64 settlementBaseAmount`: Base amount in natural units
- `uint128 settlementAttoAmount`: Fractional amount (< 1e18)
- `uint64 nominalBaseQty`: Base quantity in natural units
- `uint128 nominalAttoQty`: Fractional quantity (< 1e18)
- `string nominalCurrency`: Unit of measurement
- `bytes32[] hashes`: Array of consumption record hashes

**Validation**:
- Hash must be non-zero and unique
- Owner address must be non-zero
- Currency codes must be non-empty
- Atto amounts must be less than 1e18
- All consumption record hashes must be unique (prevents double-spending)

#### `submitBatch()`
Submits multiple consumption units in a single transaction.

**Access**: Only active CRAs

**Features**:
- Batch size limited to 100 units per transaction
- All arrays must have matching lengths
- Same validation as single submit
- Gas-efficient for multiple submissions

### Query Functions

#### `isExists(bytes32 cuHash)`
Returns whether a consumption unit exists.

#### `getRecord(bytes32 cuHash)`
Returns complete consumption unit details.

#### `getRecordsByOwner(address owner)`
Returns array of consumption unit hashes owned by an address.

### Administrative Functions

#### `setCraRegistry(address _craRegistry)` (Owner only)
Updates the CRA Registry address for access control.

#### `getCraRegistry()`
Returns the current CRA Registry address.

## Events

### `Submitted`
Emitted when a single consumption unit is submitted.
```solidity
event Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp);
```

### `BatchSubmitted`
Emitted when a batch of consumption units is submitted.
```solidity
event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);
```

## Error Handling

### Custom Errors

- `AlreadyExists()`: Consumption unit hash already exists
- `CrAlreadyExists()`: One of the consumption record hashes already used
- `CRANotActive()`: Submitting CRA is not active in registry
- `InvalidHash()`: Zero or invalid hash provided
- `InvalidOwner()`: Zero or invalid owner address
- `InvalidCurrency()`: Empty currency code provided
- `InvalidAmount()`: Atto amount >= 1e18
- `EmptyBatch()`: Empty array provided to batch function
- `BatchSizeTooLarge()`: Batch size exceeds 100
- `ArrayLengthMismatch()`: Input arrays have different lengths

## Integration Patterns

### With CRA Registry
- Validates CRA status before allowing submissions
- Dynamically updates CRA Registry reference
- Inherits access control patterns

### With Consumption Records
- References consumption record hashes for traceability
- Prevents double-spending through hash tracking
- Maintains audit trail

### With Tribute Drafts
- Provides source data for tribute draft minting
- Enforces aggregation rules (same owner, currency, day)
- Tracks usage to prevent double-spending

## Deployment Configuration

### Constructor Parameters
- None (uses initializer pattern)

### Initialization Parameters
- `address _craRegistry`: CRA Registry contract address
- `address _owner`: Contract owner address

### Required Dependencies
- CRA Registry must be deployed and configured
- OpenZeppelin UUPS proxy setup

## Usage Examples

### Basic Submission
```solidity
// Submit consumption unit (as active CRA)
consumptionUnit.submit(
    0x1234..., // cuHash
    0xOwner..., // recordOwner
    "USD", // settlementCurrency
    "2024-01-15", // worldwideDay
    100, // settlementBaseAmount (100 USD)
    500000000000000000, // settlementAttoAmount (0.5 USD)
    50, // nominalBaseQty (50 kWh)
    250000000000000000, // nominalAttoQty (0.25 kWh)
    "kWh", // nominalCurrency
    [0xabcd..., 0xefgh...] // consumption record hashes
);
```

### Query Operations
```solidity
// Check if consumption unit exists
bool exists = consumptionUnit.isExists(cuHash);

// Get full consumption unit details
ConsumptionUnitEntity memory unit = consumptionUnit.getRecord(cuHash);

// Get all units owned by address
bytes32[] memory ownerUnits = consumptionUnit.getRecordsByOwner(ownerAddress);
```

## Security Considerations

1. **Access Control**: Only active CRAs can submit consumption units
2. **Hash Uniqueness**: Prevents double-spending of consumption records
3. **Input Validation**: Comprehensive validation of all parameters
4. **Atto Precision**: Prevents overflow in fractional calculations
5. **Owner Verification**: Ensures proper ownership tracking
6. **Batch Limits**: Prevents gas limit issues with large batches

## Upgradeability

The contract uses the UUPS (Universal Upgradeable Proxy Standard) pattern:
- Implementation can be upgraded by contract owner
- Proxy address remains constant across upgrades
- State data is preserved during upgrades
- Upgrade authorization restricted to contract owner

## Gas Optimization

- Efficient storage layout for struct packing
- Batch operations for multiple submissions
- Event emission for off-chain indexing
- Minimal external calls for validation

## Monitoring and Analytics

### Key Metrics
- Total consumption units created
- Consumption units per owner
- Settlement amounts by currency
- Nominal quantities by unit type
- CRA submission activity

### Event Indexing
- Index by consumption unit hash
- Index by owner address
- Index by CRA address
- Index by settlement currency
- Index by worldwide day

## Best Practices

1. **Settlement Periods**: Use consistent worldwide day formatting
2. **Currency Standards**: Follow ISO 4217 for currency codes
3. **Precision Handling**: Use appropriate base/atto splits for amounts
4. **Batch Operations**: Prefer batch submissions for multiple units
5. **Error Handling**: Implement proper error handling for failed submissions
6. **Event Monitoring**: Set up listeners for real-time processing