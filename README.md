# Outbe L2 Contracts

Smart contracts for the Outbe Layer 2 solution, built with Foundry.

## Overview

This repository contains the core smart contracts for the Outbe L2 ecosystem, including:

- **CRA Registry**: Registry for managing Consumption Reflection Agents (CRAs)
- **Consumption Record**: Storage system for consumption record hashes with metadata  
- **Consumption Unit**: Aggregation of consumption records into settlement units with currency and amounts
- **Tribute Draft**: User-mintable tokens backed by multiple consumption units for trading/transfer
- **Upgradeable Contracts**: UUPS upgradeable versions with proxy pattern for seamless updates
- **Interfaces**: Clean contract interfaces for external integrations
- **Examples**: TypeScript integration examples

## Technology Stack

Built using **Foundry** - a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools)
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network
- **Chisel**: Fast, utilitarian, and verbose solidity REPL

## Smart Contracts

### CRA Registry (`CRARegistry.sol`)
The CRA Registry manages Consumption Reflection Agents with the following features:

**Core Functions:**
- `registerCra(address cra, string name)` - Register a new CRA (owner only)
- `updateCraStatus(address cra, CRAStatus status)` - Update CRA status (owner only)
- `isCraActive(address cra)` - Check if a CRA is active
- `getCraInfo(address cra)` - Get detailed CRA information
- `getAllCras()` - Get list of all registered CRAs

**Access Control:** Owner-controlled administrative functions

**Location**: `src/cra_registry/CRARegistry.sol`

### Consumption Record (`ConsumptionRecord.sol`)
The Consumption Record contract stores consumption record hashes with metadata:

**Core Functions:**
- `submit(bytes32 crHash, address recordOwner, string[] keys, string[] values)` - Submit consumption record (CRA only)
- `submitBatch(bytes32[] crHashes, address[] owners, string[][] keysArray, string[][] valuesArray)` - Submit multiple records in batch
- `isExists(bytes32 crHash)` - Check if record exists
- `getRecord(bytes32 crHash)` - Get complete record details
- `getRecordsByOwner(address owner)` - Get all records owned by address

**Features:**
- Secure storage of consumption data hashes
- Flexible metadata system with key-value pairs
- Batch submission support (up to 100 records per batch)
- Record ownership tracking
- Integration with CRA Registry for access control
- Only active CRAs can submit records

**Location**: `src/consumption_record/ConsumptionRecordUpgradeable.sol`

### Consumption Unit (`ConsumptionUnitUpgradeable.sol`)
The Consumption Unit contract aggregates consumption records into settlement units:

**Core Functions:**
- `submit(bytes32 cuHash, address recordOwner, string settlementCurrency, ...)` - Submit consumption unit (CRA only)
- `submitBatch(...)` - Submit multiple consumption units in batch
- `isExists(bytes32 cuHash)` - Check if consumption unit exists
- `getRecord(bytes32 cuHash)` - Get complete consumption unit details
- `getRecordsByOwner(address owner)` - Get all consumption units owned by address

**Features:**
- Settlement currency and amounts (base + atto precision)
- Nominal quantity tracking with currency denomination
- Worldwide day grouping for settlement periods
- Integration with consumption record hashes for traceability
- Comprehensive validation of amounts and currencies
- Only active CRAs can submit consumption units

**Data Structure:**
- Settlement amounts with 18-decimal precision (base + atto)
- Nominal quantities for physical unit tracking
- Consumption record hash references for audit trail
- Worldwide day string for settlement grouping

**Location**: `src/consumption_unit/ConsumptionUnitUpgradeable.sol`

### Tribute Draft (`TributeDraftUpgradeable.sol`)
The Tribute Draft contract enables users to mint tradeable tokens by aggregating consumption units:

**Core Functions:**
- `mint(bytes32[] cuHashes)` - Mint tribute draft from multiple consumption units (any user)
- `get(bytes32 tdId)` - Get tribute draft details

**Features:**
- User-mintable tokens backed by consumption units
- Aggregation validation (same owner, currency, day)  
- Automatic amount summation with overflow handling
- Unique tribute draft IDs based on CU hash combinations
- Consumption unit hash uniqueness enforcement

**Aggregation Rules:**
- All consumption units must have same owner (caller)
- All consumption units must have same settlement currency
- All consumption units must have same worldwide day
- Settlement amounts are automatically aggregated
- Each consumption unit can only be used once across all tribute drafts

**Location**: `src/tribute_draft/TributeDraftUpgradeable.sol`

### Interfaces
Clean, well-documented interfaces for external integrations:
- `ICRARegistry.sol` - CRA Registry interface
- `IConsumptionRecord.sol` - Consumption Record interface
- `IConsumptionUnit.sol` - Consumption Unit interface  
- `ITributeDraft.sol` - Tribute Draft interface

**Location**: `src/interfaces/`

## Upgradeable Contracts

All contracts in this repository use the upgradeable pattern for production deployment:

### Upgradeable Contracts
- `CRARegistryUpgradeable.sol` - UUPS upgradeable CRA registry
- `ConsumptionRecordUpgradeable.sol` - UUPS upgradeable consumption records
- `ConsumptionUnitUpgradeable.sol` - UUPS upgradeable consumption units
- `TributeDraftUpgradeable.sol` - UUPS upgradeable tribute drafts

**Key Features:**
- **UUPS Pattern**: Universal Upgradeable Proxy Standard for gas-efficient upgrades
- **Proxy Addresses**: Contract addresses remain constant across upgrades
- **State Preservation**: All data and storage layout preserved during upgrades
- **Owner-Only Upgrades**: Only contract owners can authorize upgrades
- **Comprehensive Testing**: Full test coverage for upgrade scenarios

**Contract Flow Architecture:**
```
┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   CRA Registry   │    │ Consumption     │    │ Consumption Unit │    │ Tribute Draft    │
│                  │    │ Record          │    │                  │    │                  │
└─────────┬────────┘    └─────────┬───────┘    └─────────┬────────┘    └─────────┬────────┘
          │                       │                      │                       │
          │ 1. Register CRA       │                      │                       │
          │                       │ 2. Submit CR hashes  │                       │
          │                       │                      │ 3. Aggregate CRs      │
          │                       │                      │    into CUs           │
          │                       │                      │                       │ 4. Mint tradeable
          │                       │                      │                       │    tribute drafts
          │                       │                      │                       │    from CUs
          ▼                       ▼                      ▼                       ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              UUPS Proxy Pattern                                          │
│  ┌─────────────────┐    ┌──────────────────────┐                                         │
│  │   User/Client   │    │    Implementation    │                                         │
│  │                 │    │     Contract v2      │                                         │
│  └─────────┬───────┘    └──────────┬───────────┘                                         │
│            │                       │                                                     │
│            │ delegatecall          │                                                     │
│            ▼                       │                                                     │
│  ┌─────────────────┐               │                                                     │
│  │  Proxy Contract │───────────────┘                                                     │
│  │ (Fixed Address) │                                                                     │
│  │ (Stores State)  │                                                                     │
│  └─────────────────┘                                                                     │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

**Usage:**
- **Deploy**: Use `DeployUpgradeable.s.sol` for initial deployment
- **Upgrade**: Use `UpgradeImplementations.s.sol` to update contract logic
- **Interact**: Always use proxy addresses for all interactions

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [CRA Registry Documentation](./docs/cra-registry.md)
- [Consumption Record Documentation](./docs/consumption-record.md)
- [Consumption Unit Documentation](./docs/consumption-unit.md)
- [Tribute Draft Documentation](./docs/tribute-draft.md)
- [TypeScript Examples](./examples/README.md)
- [CREATE2 Deployment Guide](./docs/create2-deployment.md)

## Usage

### Development Commands

**Build contracts:**
```shell
forge build
```

**Run tests:**
```shell
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run specific test
forge test --match-test test_RegisterCRA

# Run tests for specific contract
forge test --match-contract CRARegistryTest
```

**Code quality:**
```shell
# Format code
forge fmt

# Lint code for security and style issues
forge lint

# Generate gas snapshots
forge snapshot

# Generate test coverage
forge coverage
```

**Documentation:**
```shell
# Generate documentation from NatSpec
forge doc
```

### Local Development

**Start local node:**
```shell
anvil
```

**Deploy to local network:**
```shell
# Deploy upgradeable contracts with proxy pattern
forge script script/DeployUpgradeable.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>

# Deploy to testnet with verification
forge script script/DeployUpgradeable.s.sol --rpc-url http://rpc.dev.outbe.net:8545 --broadcast --verify --private-key <PRIVATE_KEY>

# Deploy with custom salt to avoid collisions
SALT_SUFFIX=prod_v1 forge script script/DeployUpgradeable.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>

# Deploy with unique timestamp salt for testing
USE_TIMESTAMP_SALT=true forge script script/DeployUpgradeable.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

**Note on CREATE2 Factory:**
If you encounter "missing CREATE2 deployer" error, first deploy the CREATE2 factory:

```shell
# Deploy CREATE2 factory (only needed once per chain)
forge script script/DeployCREATE2Factory.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>

# Alternative: Deploy without CREATE2 for immediate use
forge script script/DeployWithoutCREATE2.s.sol --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>

# Check if CREATE2 factory exists on your chain
cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <RPC_URL>
```

**Upgrade contracts:**
```shell
# Upgrade implementations while preserving proxy addresses and data
CRA_REGISTRY_ADDRESS=<proxy_address> CONSUMPTION_RECORD_ADDRESS=<proxy_address> forge script script/UpgradeImplementations.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>

# Upgrade only specific contracts
UPGRADE_CRA_REGISTRY=true UPGRADE_CONSUMPTION_RECORD=false forge script script/UpgradeImplementations.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <PRIVATE_KEY>
```

### Interacting with Contracts

**Using Cast:**
```shell
# Get CRA info
cast call <CRA_REGISTRY_ADDRESS> "getCraInfo(address)" <CRA_ADDRESS>

# Check if CRA is active
cast call <CRA_REGISTRY_ADDRESS> "isCraActive(address)" <CRA_ADDRESS>

# Submit consumption record (as CRA)
cast send <CONSUMPTION_RECORD_ADDRESS> "submit(bytes32,address,string[],string[])" <CR_HASH> <RECORD_OWNER> '["key1","key2"]' '["value1","value2"]' --private-key <PRIVATE_KEY>

# Get consumption records by owner  
cast call <CONSUMPTION_RECORD_ADDRESS> "getRecordsByOwner(address)" <OWNER_ADDRESS>

# Get consumption record details
cast call <CONSUMPTION_RECORD_ADDRESS> "getRecord(bytes32)" <CR_HASH>

# Submit consumption unit (as CRA)
cast send <CONSUMPTION_UNIT_ADDRESS> "submit(bytes32,address,string,string,uint64,uint128,uint64,uint128,string,bytes32[])" <CU_HASH> <OWNER> <SETTLEMENT_CURRENCY> <WORLDWIDE_DAY> <SETTLEMENT_BASE> <SETTLEMENT_ATTO> <NOMINAL_BASE> <NOMINAL_ATTO> <NOMINAL_CURRENCY> '[<CR_HASH_1>,<CR_HASH_2>]' --private-key <PRIVATE_KEY>

# Get consumption unit details
cast call <CONSUMPTION_UNIT_ADDRESS> "getRecord(bytes32)" <CU_HASH>

# Mint tribute draft (as consumption unit owner)
cast send <TRIBUTE_DRAFT_ADDRESS> "mint(bytes32[])" '[<CU_HASH_1>,<CU_HASH_2>]' --private-key <PRIVATE_KEY>

# Get tribute draft details
cast call <TRIBUTE_DRAFT_ADDRESS> "get(bytes32)" <TD_ID>
```

## Project Structure

```
outbe-l2-contracts/
├── src/                                    # Smart contracts source code
│   ├── interfaces/                         # Contract interfaces
│   │   ├── ICRARegistry.sol               # CRA Registry interface
│   │   ├── IConsumptionRecord.sol         # Consumption Record interface
│   │   ├── IConsumptionUnit.sol           # Consumption Unit interface
│   │   └── ITributeDraft.sol              # Tribute Draft interface
│   ├── cra_registry/                      # CRA Registry implementation
│   │   └── CRARegistryUpgradeable.sol     # UUPS upgradeable CRA Registry contract
│   ├── consumption_record/                # Consumption Record implementation
│   │   └── ConsumptionRecordUpgradeable.sol # UUPS upgradeable Consumption Record contract
│   ├── consumption_unit/                  # Consumption Unit implementation
│   │   └── ConsumptionUnitUpgradeable.sol # UUPS upgradeable Consumption Unit contract
│   └── tribute_draft/                     # Tribute Draft implementation
│       └── TributeDraftUpgradeable.sol    # UUPS upgradeable Tribute Draft contract
├── test/                                  # Test files
│   ├── cra_registry/                      # CRA Registry tests
│   │   └── CRARegistryUpgradeable.t.sol   # Comprehensive test suite
│   ├── consumption_record/                # Consumption Record tests
│   │   └── ConsumptionRecordUpgradeable.t.sol # Comprehensive test suite
│   ├── consumption_unit/                  # Consumption Unit tests
│   │   └── ConsumptionUnitUpgradeable.t.sol # Comprehensive test suite
│   ├── tribute_draft/                     # Tribute Draft tests
│   │   └── TributeDraftUpgradeable.t.sol  # Comprehensive test suite
│   ├── deployment/                        # Deployment tests
│   │   └── CREATE2Deployment.t.sol        # CREATE2 deployment tests
│   └── upgrades/                          # Upgrade workflow tests
│       └── UpgradeWorkflow.t.sol          # UUPS upgrade tests
├── script/                                # Deployment and interaction scripts
│   ├── DeployUpgradeable.s.sol            # Upgradeable deployment with proxy pattern
│   ├── UpgradeImplementations.s.sol       # Contract upgrade script
│   └── PredictAddresses.s.sol             # CREATE2 address prediction script
├── docs/                                  # Documentation
│   ├── cra-registry.md                    # CRA Registry docs
│   └── consumption-record.md              # Consumption Record docs
├── examples/                              # TypeScript integration examples
│   ├── cra-registry.ts                    # CRA Registry examples
│   ├── consumption-record.ts              # Consumption Record examples
│   ├── consumption-unit.ts                # Consumption Unit examples
│   ├── tribute-draft.ts                   # Tribute Draft examples
│   └── package.json                       # Node.js dependencies
└── lib/                                   # Dependencies (Foundry submodules)
    └── forge-std/                         # Foundry standard library
```

## Testing

The project includes comprehensive test suites with:

- **Unit Tests**: Testing individual contract functions
- **Integration Tests**: Testing contract interactions
- **Fuzz Tests**: Property-based testing with random inputs
- **Edge Case Tests**: Testing boundary conditions and error states

**Test Coverage:**
- CRARegistry: 15+ tests covering registration, status updates, and access control
- ConsumptionRecord: 19+ tests covering submissions, batch operations, metadata, ownership tracking, and validation  
- ConsumptionUnit: 20+ tests covering submissions, batch operations, amount validation, currency validation, and consumption record hash tracking
- TributeDraft: 15+ tests covering minting, aggregation validation, duplicate prevention, and ownership verification
- Deployment & Upgrades: Tests for CREATE2 deployment and UUPS upgrade workflows
- All critical paths and error conditions are tested

## Security

This codebase follows Solidity security best practices:

- **Access Control**: Owner-only administrative functions
- **Input Validation**: Comprehensive validation of all inputs
- **Error Handling**: Custom errors for gas-efficient error reporting
- **Reentrancy Protection**: Following checks-effects-interactions pattern
- **Code Quality**: Automated linting and formatting
- **Deterministic Deployment**: Uses CREATE2 with salt for deterministic contract addresses
- **Explicit Ownership**: Constructors accept explicit owner parameters to avoid CREATE2 ownership issues
- **Upgradeable Architecture**: UUPS proxy pattern for seamless contract updates while preserving state and addresses
- **Comprehensive Testing**: Unit, integration, and upgrade tests ensuring contract reliability

## Help

```shell
forge --help    # Foundry help
anvil --help    # Local node help  
cast --help     # Blockchain interaction help
```
