# CRA Registry Contract

## Overview

The `CRARegistryUpgradeable` contract is an upgradeable registry for managing Consumption Reflection Agents (CRAs). It provides centralized management of CRA registration, status updates, and access control for the consumption record system using the UUPS (Universal Upgradeable Proxy Standard) pattern.

## Contract Details

- **Version**: 1.0.0
- **License**: MIT
- **Solidity Version**: ^0.8.13
- **Location**: `src/cra_registry/CRARegistryUpgradeable.sol`
- **Pattern**: UUPS Upgradeable Proxy
- **Deployment**: CREATE2 deterministic addresses

**Key Features:**

- Registry of CRA addresses with their information
- Status management for CRAs (Active, Inactive, Suspended)
- Owner-controlled access for administrative functions
- UUPS upgradeable pattern for seamless updates
- CREATE2 deterministic deployment addresses
- Initializer pattern instead of constructor

## Core Data Structures

### CRAStatus Enum

```solidity
enum CRAStatus {
    Inactive,  // 0: CRA is not active
    Active,    // 1: CRA is active and can submit records
    Suspended  // 2: CRA is temporarily suspended
}
```

### CraInfo Struct

```solidity
struct CraInfo {
    string name;           // Human-readable name of the CRA
    CRAStatus status;      // Current status
    uint256 registeredAt;  // Registration timestamp
}
```

## State Variables

- `cras`: Mapping from CRA address to CraInfo
- `craList`: Array of all registered CRA addresses
- Inherited from `OwnableUpgradeable`: Owner functionality
- Inherited from `UUPSUpgradeable`: Upgrade authorization

## Access Control

### Modifiers

- `onlyOwner`: Restricts access to contract owner
- `craExists`: Ensures CRA is registered before operations

## Core Functions

### Initialization

#### initialize()

```solidity
function initialize(address _owner) public initializer
```

Initializes the upgradeable contract (replaces constructor).

**Requirements:**

- Can only be called once (initializer modifier)
- Owner cannot be zero address

**Effects:**

- Initializes OpenZeppelin upgradeable components
- Sets the contract owner

### CRA Management

#### registerCra()

```solidity
function registerCRA(address cra, string calldata name) external onlyOwner
```

Registers a new CRA in the system.

**Requirements:**

- Only callable by owner
- CRA must not already be registered
- Name cannot be empty

**Effects:**

- Adds CRA to registry with Active status
- Adds to CRA list
- Sets registration timestamp

**Events Emitted:**

- `CRARegistered(cra, name, block.timestamp)`

### updateCraStatus()

```solidity
function updateCRAStatus(address cra, CRAStatus status) external onlyOwner craExists(cra)
```

Updates the status of an existing CRA.

**Requirements:**

- Only callable by owner
- CRA must be registered

**Events Emitted:**

- `CRAStatusUpdated(cra, oldStatus, newStatus, block.timestamp)`

### Query Functions

#### isCraActive()

```solidity
function isCRAActive(address cra) external view returns (bool)
```

Returns true if CRA is registered and has Active status.

#### getCraInfo()

```solidity
function getCRAInfo(address cra) external view craExists(cra) returns (CraInfo memory)
```

Returns complete CRA information for registered CRAs.

#### getAllCRAs()

```solidity
function getAllCRAs() external view returns (address[] memory)
```

Returns array of all registered CRA addresses.

### Administrative Functions

- `getOwner()`: Get contract owner address (from OwnableUpgradeable)
- `transferOwnership(address newOwner)`: Transfer ownership to new address (from OwnableUpgradeable)

## Events

```solidity
event CRARegistered(address indexed cra, string name, uint256 timestamp);
event CRAStatusUpdated(
    address indexed cra,
    CRAStatus oldStatus,
    CRAStatus newStatus,
    uint256 timestamp
);
```

## Custom Errors

- `CRANotFound()`: CRA is not registered in the system
- `CRAAlreadyRegistered()`: Attempting to register an already registered CRA
- `InvalidCRAStatus()`: Invalid status value provided
- `UnauthorizedAccess()`: Caller is not authorized for the operation
- `EmptyCRAName()`: Empty name provided during registration

## CRA Lifecycle

1. **Registration**: Owner registers CRA with name → Status: Active
2. **Status Management**: Owner can change status to Inactive or Suspended
3. **Reactivation**: Owner can change status back to Active
4. **No Removal**: CRAs cannot be removed once registered, only status changes

## Usage Example

See the TypeScript example in [create-active-cra.ts](../examples/scripts/create-active-cra.ts).
