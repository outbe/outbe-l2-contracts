# Outbe L2 Contracts

Smart contracts for the Outbe Layer 2 chain.

## Requirements

- [Foundry](https://getfoundry.sh/)
- Npm and TypeScript (for running examples)
- Make

## How To Build And Deploy

_To see all available commands, run `make`._

**Build contracts:**

```shell
make build
```

### Local Development

**Start local node:**

```shell
anvil
```

**Deploy to local network:** (on a second terminal)

```shell
make deploy-local
```

Now you should see the deployed contracts addresses in the terminal output.

## Overview

This repository contains the core smart contracts for the Outbe L2 ecosystem, including:

- **CRA Registry**: Registry for managing Consumption Reflection Agents (CRAs)
- **Consumption Record**: Smart contract for consumption record hashes with metadata
- **Consumption Record Amendment**: Smart contract for consumption record amendment hashes with metadata
- **Consumption Unit**: Aggregation of consumption records into settlement units with currency and amounts
- **Tribute Draft**: User-mintable tokens backed by multiple consumption units
- **Examples**: TypeScript integration examples

**Contract Flow Architecture:**

```
┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   CRA Registry   │    │ Consumption     │    │ Consumption Unit │    │ Tribute Draft    │
│                  │    │ Record          │    │                  │    │                  │
└─────────┬────────┘    └─────────┬───────┘    └─────────┬────────┘    └─────────┬────────┘
          │                       │                      │                       │
          │ 1. Register CRA       │                      │                       │
          │                       │ 2. Submit CRs        │                       │
          │                       │                      │ 3. Aggregate CRs      │
          │                       │                      │    into CUs           │
          │                       │                      │                       │ 4. Submit
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

## Smart Contracts In-Depth

### CRA Registry

The CRA Registry manages Consumption Reflection Agents with the following features:

**Core Functions:**

- `registerCRA(address cra, string name)` - Register a new CRA (owner only)
- `updateCRAStatus(address cra, CRAStatus status)` - Update CRA status (owner only)
- `isCRAActive(address cra)` - Check if a CRA is active
- `getCRAInfo(address cra)` - Get detailed CRA information
- `getAllCRAs()` - Get list of all registered CRAs

**Access Control:** Owner-controlled administrative functions

For more information, see the [CRA Registry documentation](./docs/cra-registry.md).

### Consumption Record

The Consumption Record contract stores consumption record hashes with metadata. Only Active CRAs can submit records.

**Core Functions:**

- `submit(bytes32 crHash, address owner, string[] keys, string[] values)` - Submit consumption record (CRA only)
- `isExists(bytes32 crHash)` - Check if record exists
- `getConsumptionRecord(bytes32 crHash)` - Get complete record details
- `getConsumptionRecordsByOwner(address owner)` - Get all records owned by the given address

**Features:**

- Secure storage of consumption data hashes
- Flexible metadata system with key-value pairs
- Batch submission support (up to 100 records per batch) via Multicall.

For more information, see the [Consumption Record ADR](./docs/adrs/0001-consumption-record.md).

### Consumption Record Amendment

The Consumption Record Amendment contract stores consumption record amendments i.e.,
information about tx refunds etc. Only Active CRAs can submit records.

**Core Functions:**

- `submit(bytes32 crAmendmentHash, address owner, string[] keys, string[] values)` - Submit consumption record amendment (CRA only)
- `isExists(bytes32 crAmendmentHash)` - Check if amendment record exists
- `getConsumptionRecordAmendment(bytes32 crAmendmentHash)` - Get complete amendment details
- `getConsumptionRecordAmendmentsByOwner(address owner)` - Get all amendment records owned by the given address

**Features:**

- Secure storage of consumption data hashes for amendment
- Flexible metadata system with key-value pairs
- Batch submission support (up to 100 records per batch) via Multicall.

For more information, see the [Consumption Record ADR](./docs/adrs/0004-consumption-record-amendment.md).

### Consumption Unit

The Consumption Unit contract aggregates consumption records (and ammendment consumption records if any)
into consumption units. Only Active CRAs can submit records.

**Core Functions:**

- `submit(bytes32 cuHash, address owner, string settlementCurrency, ...)` - Submit consumption unit (CRA only)
- `isExists(bytes32 cuHash)` - Check if consumption unit exists
- `getConsumptionUnit(bytes32 cuHash)` - Get complete consumption unit details
- `getConsumptionUnitsByOwner(address owner)` - Get all consumption units owned by address

**Features:**

- Integration with consumption record hashes for traceability
- Worldwide day grouping for consumption
- Settlement currency and amounts (base + atto precision)
- Batch submission support (up to 100 records per batch) via Multicall.

For more information, see the [Consumption Unit ADR](./docs/adrs/0002-consumption-unit.md).

### Tribute Draft

The Tribute Draft contract enables users to mint non-fungible self-bound tokens by aggregating consumption units:

**Core Functions:**

- `submit(bytes32[] cuHashes)` - Mint tribute draft from multiple consumption units (any user)
- `getTributeDraft(bytes32 tdId)` - Get tribute draft details

**Features:**

- User-mintable tokens backed by consumption units
- Aggregation validation (same owner, currency, day)
- Unique tribute draft IDs based on CU hash combinations
- Consumption unit hash uniqueness enforcement

**Aggregation Rules:**

- All consumption units must have same owner (caller)
- All consumption units must have same settlement currency
- All consumption units must have same worldwide day
- Settlement amounts are automatically aggregated
- Each consumption unit can only be used once across all tribute drafts

For more information, see the [Tribute Draft ADR](./docs/adrs/0003-tribute-draft.md).

## Upgradeable Contracts

All contracts in this repository use the upgradeable pattern for production deployment:

- `CRARegistryUpgradeable.sol` - UUPS upgradeable CRA registry
- `ConsumptionRecordUpgradeable.sol` - UUPS upgradeable consumption records
- `ConsumptionRecordAmendmentUpgradeable.sol` - UUPS upgradeable consumption records amendments
- `ConsumptionUnitUpgradeable.sol` - UUPS upgradeable consumption units
- `TributeDraftUpgradeable.sol` - UUPS upgradeable tribute drafts

**Key Features:**

- **UUPS Pattern**: Universal Upgradeable Proxy Standard for gas-efficient upgrades
- **Proxy Addresses**: Contract addresses remain constant across upgrades
- **State Preservation**: All data and storage layout preserved during upgrades
- **Owner-Only Upgrades**: Only contract owners can authorize upgrades

## Interacting with Contracts

See the [TypeScript Examples](./examples/README.md) for examples of interacting with the contracts.

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [ADRs](./docs/adrs)
- [CRA Registry Documentation](./docs/cra-registry.md)
- [CREATE2 Deployment Guide](./docs/create2-deployment.md)
- [TypeScript Examples](./examples/README.md)

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
make # To see all available commands
forge --help    # Foundry help
anvil --help    # Local node help  
cast --help     # Blockchain interaction help
```

## Using the Test Container (Docker)

This project includes a Dockerized Anvil testnet preloaded with the Outbe L2 contracts. The image is built in two stages:
- Stage 1 starts Anvil, deploys contracts via Forge script, and snapshots the chain state to anvil-state.json.
- Stage 2 runs Anvil with that state and provides a simple entrypoint that can optionally register a CRA for you.

### Run the container
- Basic run (exposes RPC on 8545):
  ```sh
    docker run --rm -p 8545:8545 --name outbe-anvil ghcr.io/outbe/outbe-l2-test-node:latest
  ```
- Run with auto-registering a CRA address and fund it with 1000 ETH on startup:
  ```sh
  docker run --rm -p 8545:8545 \
    -e CRA_REGISTRY_PROXY=<RequiredToProvideHere> \
    -e CRA_ADDRESS=0xYourCraAddressHere \
    --name outbe-anvil outbe-l2-test
  ```
### Environment variables (with defaults in the image)
- OWNER_PRIVATE_KEY: `0xac0974...ff80` (Anvil default first key)
- OWNER_ADDRESS: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- CRA_REGISTRY_PROXY: required to provide here
- CRA_ADDRESS: if set, entrypoint registers this CRA in the registry and funds it

### Readiness and health
- Logs will print `READY` when the node is up and `CRA REGISTERED` if a CRA address was provided
- You can also wait for Docker health status to become healthy (readiness only):
  ```sh
  docker inspect --format='{{json .State.Health.Status}}' outbe-anvil
  ```
