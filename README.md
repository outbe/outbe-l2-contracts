# Outbe L2 Contracts

Smart contracts for the Outbe Layer 2 solution, built with Foundry.

## Overview

This repository contains the core smart contracts for the Outbe L2 ecosystem, including:

- **CRA Registry**: Registry for managing Consumption Reflection Agents (CRAs)
- **Consumption Record**: Storage system for consumption record hashes with metadata
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
- `submit(bytes32 crHash, string[] keys, string[] values)` - Submit consumption record (CRA only)
- `isExists(bytes32 crHash)` - Check if record exists
- `getDetails(bytes32 crHash)` - Get record details
- `getMetadata(bytes32 crHash, string key)` - Get specific metadata
- `getMetadataKeys(bytes32 crHash)` - Get all metadata keys

**Features:**
- Secure storage of consumption data hashes
- Flexible metadata system with key-value pairs
- Integration with CRA Registry for access control
- Only active CRAs can submit records

**Location**: `src/consumption_record/ConsumptionRecord.sol`

### Interfaces
Clean, well-documented interfaces for external integrations:
- `ICRARegistry.sol` - CRA Registry interface
- `IConsumptionRecord.sol` - Consumption Record interface

**Location**: `src/interfaces/`

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
# Deploy CRA Registry
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy with verification on testnet
forge script script/Deploy.s.sol --rpc-url http://rpc.dev.outbe.net:8545 --broadcast --verify
```

### Interacting with Contracts

**Using Cast:**
```shell
# Get CRA info
cast call <CRA_REGISTRY_ADDRESS> "getCraInfo(address)" <CRA_ADDRESS>

# Check if CRA is active
cast call <CRA_REGISTRY_ADDRESS> "isCraActive(address)" <CRA_ADDRESS>

# Submit consumption record (as CRA)
cast send <CONSUMPTION_RECORD_ADDRESS> "submit(bytes32,string[],string[])" <CR_HASH> '["key1","key2"]' '["value1","value2"]' --private-key <PRIVATE_KEY>
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
│   └── Counter.s.sol                      # Deployment scripts
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
- ConsumptionRecord: 19 tests covering submissions, metadata, and validation
- All critical paths and error conditions are tested

## Security

This codebase follows Solidity security best practices:

- **Access Control**: Owner-only administrative functions
- **Input Validation**: Comprehensive validation of all inputs
- **Error Handling**: Custom errors for gas-efficient error reporting
- **Reentrancy Protection**: Following checks-effects-interactions pattern
- **Code Quality**: Automated linting and formatting

## Help

```shell
forge --help    # Foundry help
anvil --help    # Local node help  
cast --help     # Blockchain interaction help
```
