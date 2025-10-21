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

## Architecture

The contract implements the `ICRARegistry` interface and uses the UUPS upgradeable pattern:

```
User/Client → Proxy Contract → Implementation Contract
              (Fixed Address)   (Upgradeable Logic)
              (Stores State)
```

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
function registerCra(address cra, string calldata name) external onlyOwner
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
function updateCraStatus(address cra, CRAStatus status) external onlyOwner craExists(cra)
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
function isCraActive(address cra) external view returns (bool)
```
Returns true if CRA is registered and has Active status.

#### getCraInfo()
```solidity
function getCraInfo(address cra) external view craExists(cra) returns (CraInfo memory)
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

## Status Definitions

- **Inactive (0)**: CRA is not permitted to submit consumption records
- **Active (1)**: CRA can submit consumption records and perform operations  
- **Suspended (2)**: CRA is temporarily disabled but remains registered

## Security Considerations

1. **Centralized Control**: Only owner can register CRAs and manage statuses
2. **Immutable Registration**: CRAs cannot be removed once registered
3. **Status Flexibility**: Owner can quickly suspend/reactivate CRAs as needed
4. **Access Control**: All administrative functions protected by owner modifier
5. **Ownership Transfer**: Owner can transfer control to new address

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
# Register a new CRA (owner only)
cast send <PROXY_ADDRESS> "registerCra(address,string)" <CRA_ADDRESS> "My CRA Service" --private-key <PRIVATE_KEY>

# Check if CRA is active
cast call <PROXY_ADDRESS> "isCraActive(address)" <CRA_ADDRESS>

# Update CRA status (owner only)
cast send <PROXY_ADDRESS> "updateCraStatus(address,uint8)" <CRA_ADDRESS> 2 --private-key <PRIVATE_KEY>

# Get all CRAs
cast call <PROXY_ADDRESS> "getAllCRAs()"

# Get contract version
cast call <PROXY_ADDRESS> "VERSION()"
```

## Usage Example

```solidity
// Get the deployed proxy address (not the implementation!)
CRARegistryUpgradeable registry = CRARegistryUpgradeable(<PROXY_ADDRESS>);

// Register a new CRA (owner only)
registry.registerCra(craAddress, "My CRA Service");

// Check if CRA is active
bool isActive = registry.isCraActive(craAddress);

// Update CRA status (owner only)
registry.updateCraStatus(craAddress, CRAStatus.Suspended);

// Get all CRAs
address[] memory allCRAs = registry.getAllCRAs();

// Upgrade the contract (owner only)
registry.upgradeTo(newImplementationAddress);
```

## Integration with Consumption Record

The CRA Registry serves as the authority for:
- Determining which addresses can submit consumption records
- Providing CRA validation for the ConsumptionRecordUpgradeable contract
- Centralized management of CRA permissions

The ConsumptionRecordUpgradeable contract queries `isCraActive()` to verify permissions before allowing record submissions.

**Important:** Both contracts use the same proxy pattern and CREATE2 deployment for consistent addresses across networks.

## Testing Coverage

The contract includes comprehensive test coverage:
- Registration validation and events
- Status update functionality
- Access control enforcement
- Edge cases and error conditions
- Fuzz testing for name validation
- Multi-CRA scenarios
- Ownership transfer functionality