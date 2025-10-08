# CRAAware Base Contract

## Overview

`CRAAware` is a lightweight base contract designed to be inherited by other upgradeable contracts that need to restrict certain functions to active CRA (Consumption Reflection Agent) addresses. It integrates with the on-chain CRA Registry to verify that the caller is currently active.

This contract does not implement business logic itself; it provides:
- A registry reference (`craRegistry`)
- An initializer to set the registry (`__CRAAware_init`)
- A reusable access-control modifier (`onlyActiveCRA`)
- Helper functions for checking and reading the registry

## Contract Details

- License: MIT
- Solidity Version: ^0.8.13
- Location: `src/utils/CRAAware.sol`
- Intended Usage: Inheritance by upgradeable contracts (Initializer pattern)

## When to Use CRAAware

Use `CRAAware` when your contract must ensure that only active CRAs can call specific functions. This is common for submission-type actions (e.g., submitting consumption records or units) that must be performed by authorized agents.

## Public and Internal API

### State

- `ICRARegistry public craRegistry`  
  Reference to the CRA Registry used to validate whether a caller is an active CRA.

### Modifiers

- `onlyActiveCRA`  
  Restricts a function so that only addresses that are active in the CRA Registry can call it. Under the hood this calls `_checkActiveCra()` which reverts with `"CRA not active"` if the caller is not active.

### Initializer

- `function __CRAAware_init(address _craRegistry) internal onlyInitializing`  
  Sets the CRA Registry address. Should be called from the child contract's initializer.

  Requirements:
  - `_craRegistry` must not be the zero address

### Internal Helpers

- `function _checkActiveCra() internal view`  
  Reverts with `"CRA not active"` if `msg.sender` is not an active CRA in the registry.

- `function _setRegistry(address _craRegistry) internal`  
  Internal helper used by the initializer. Reverts if `_craRegistry` is the zero address. Sets `craRegistry`.

### External Views

- `function registry() external view returns (address)`  
  Returns the address of the current CRA Registry.

## Integration Guide

1. Inherit from CRAAware in your upgradeable contract:

```solidity
import {CRAAware} from "../utils/CRAAware.sol";

contract MyFeature is CRAAware, Initializable {
    function initialize(address craRegistry, /* other params */) public initializer {
        __CRAAware_init(craRegistry);
        // initialize other parents / state
    }

    function submitSomething(bytes32 id) external onlyActiveCRA {
        // logic that only active CRA addresses can execute
    }
}
```

2. Ensure the CRA Registry is deployed and configured, and that the callers are registered and active in it.

## Related Contracts

- CRA Registry: `CRARegistryUpgradeable` (docs: `docs/cra-registry.md`)
- Consumption Records: `ConsumptionRecordUpgradeable` (docs: `docs/consumption-record.md`)
- Consumption Units: `ConsumptionUnitUpgradeable` (docs: `docs/consumption-unit.md`)

## Notes

- CRAAware uses the Initializer pattern and is intended for upgradeable contracts. It imports OpenZeppelin `Initializable` and `Context`.
- The modifier name is `onlyActiveCRA` (uppercase "CRA"), while some other contracts may use a similarly named local modifier; this base modifier is provided for reuse across implementations that adopt the CRA registry model. 