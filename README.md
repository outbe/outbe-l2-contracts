# Outbe L2 Contracts

Smart contracts for the Outbe Layer 2 solution, built with Foundry.

## Overview

This repository contains the core smart contracts for the Outbe L2 ecosystem, including:

- **CRA Registry**: Registry for managing Consumption Reflection Agents (CRAs)
- **Consumption Record**: Storage system for consumption record hashes with metadata
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

**Location**: `src/consumption_record/ConsumptionRecord.sol`

### Interfaces
Clean, well-documented interfaces for external integrations:
- `ICRARegistry.sol` - CRA Registry interface
- `IConsumptionRecord.sol` - Consumption Record interface

**Location**: `src/interfaces/`

## Upgradeable Contracts

The repository provides both standard and upgradeable versions of the contracts:

### Standard Contracts
- `CRARegistry.sol` - Non-upgradeable registry
- `ConsumptionRecord.sol` - Non-upgradeable consumption records

### Upgradeable Contracts (Recommended)
- `CRARegistryUpgradeable.sol` - UUPS upgradeable registry
- `ConsumptionRecordUpgradeable.sol` - UUPS upgradeable consumption records

**Key Features:**
- **UUPS Pattern**: Universal Upgradeable Proxy Standard for gas-efficient upgrades
- **Proxy Addresses**: Contract addresses remain constant across upgrades
- **State Preservation**: All data and storage layout preserved during upgrades
- **Owner-Only Upgrades**: Only contract owners can authorize upgrades
- **Comprehensive Testing**: Full test coverage for upgrade scenarios

**Architecture:**
```
┌─────────────────┐    ┌──────────────────────┐
│   User/Client   │    │    Implementation    │
│                 │    │     Contract v2      │
└─────────┬───────┘    └──────────┬───────────┘
          │                       │
          │ delegatecall           │
          ▼                       │
┌─────────────────┐              │
│  Proxy Contract │──────────────┘
│ (Fixed Address) │
│ (Stores State)  │
└─────────────────┘
```

**Usage:**
- **Deploy**: Use `DeployUpgradeable.s.sol` for initial deployment
- **Upgrade**: Use `UpgradeImplementations.s.sol` to update contract logic
- **Interact**: Always use proxy addresses for all interactions

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [CRA Registry Documentation](./docs/cra-registry.md)
- [Consumption Record Documentation](./docs/consumption-record.md)
- [TypeScript Examples](./examples/README.md)

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

# Get records by owner
cast call <CONSUMPTION_RECORD_ADDRESS> "getRecordsByOwner(address)" <OWNER_ADDRESS>

# Get record details
cast call <CONSUMPTION_RECORD_ADDRESS> "getRecord(bytes32)" <CR_HASH>
```

## Project Structure

```
outbe-l2-contracts/
├── src/                                    # Smart contracts source code
│   ├── interfaces/                         # Contract interfaces
│   │   ├── ICRARegistry.sol               # CRA Registry interface
│   │   └── IConsumptionRecord.sol         # Consumption Record interface
│   ├── cra_registry/                      # CRA Registry implementation
│   │   └── CRARegistry.sol                # Main CRA Registry contract
│   ├── consumption_record/                # Consumption Record implementation
│   │   └── ConsumptionRecord.sol          # Main Consumption Record contract
│   └── consumption_unit/                  # Utility contracts
│       └── Counter.sol                    # Basic counter for testing
├── test/                                  # Test files
│   ├── cra_registry/                      # CRA Registry tests
│   │   └── CRARegistry.t.sol              # Comprehensive test suite
│   ├── consumption_record/                # Consumption Record tests
│   │   └── ConsumptionRecord.t.sol        # Comprehensive test suite
│   └── consumption_unit/                  # Utility tests
│       └── Counter.t.sol                  # Counter tests
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
- CRARegistry: 15 tests covering registration, status updates, and access control
- ConsumptionRecord: 19+ tests covering submissions, batch operations, metadata, ownership tracking, and validation
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
