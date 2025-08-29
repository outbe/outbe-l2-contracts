# Outbe L2 Contracts

Smart contracts for the Outbe Layer 2 solution, built with Foundry.

## Overview

This repository contains the core smart contracts for the Outbe L2 ecosystem, including:

- **Consumption Unit**: (To be implemented)
- **Consumption Record**: (To be implemented)
- **Tribute Draft**: (To be implemented)

## Technology Stack

Built using **Foundry** - a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools)
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network
- **Chisel**: Fast, utilitarian, and verbose solidity REPL

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Project Documentation](./docs/)

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Project Structure

```
├── src/                          # Smart contracts source code
│   ├── consumption_unit/         # Consumption tracking contracts
│   │   └── Counter.sol          # Basic counter implementation
│   ├── consumption_record/       # Consumption record contracts (TBD)
│   └── tribute_draft/           # Tribute draft contracts (TBD)
├── test/                        # Test files
│   └── consumption_unit/        # Tests for consumption unit contracts
│       └── Counter.t.sol       # Counter contract tests
├── script/                      # Deployment and interaction scripts
│   └── Counter.s.sol           # Counter deployment script
└── lib/                        # Dependencies (Foundry submodules)

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
