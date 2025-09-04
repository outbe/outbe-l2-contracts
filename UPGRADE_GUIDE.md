# Contract Upgrade Guide

This guide explains how to deploy and upgrade the Outbe L2 contracts using the UUPS proxy pattern.

## Overview

The Outbe L2 contracts use the UUPS (Universal Upgradeable Proxy Standard) pattern, which allows you to:
- Update contract logic while preserving addresses and state
- Fix bugs and add new features without losing data
- Maintain seamless user experience across upgrades

## Architecture

```
User/Client → Proxy Contract → Implementation Contract
              (Fixed Address)   (Upgradeable Logic)
              (Stores State)
```

### CREATE2 Deterministic Deployment

The upgradeable contracts use **CREATE2** for deterministic address generation:

- **Proxy addresses** are deterministic and remain constant across all networks
- **Implementation addresses** are also deterministic for easy verification
- Uses standard CREATE2 factory: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
- Salt-based deployment prevents address collisions

**Benefits:**
- Same addresses across different networks (testnet, mainnet)
- Predictable addresses for frontend integration
- No need to reconfigure client applications after deployment
- Cross-chain consistency for multi-chain deployments

## Initial Deployment

### 1. Deploy Upgradeable Contracts

```bash
# Deploy to local Anvil network
forge script script/DeployUpgradeable.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key <PRIVATE_KEY>

# Deploy to testnet
forge script script/DeployUpgradeable.s.sol \
  --rpc-url <TESTNET_RPC_URL> \
  --broadcast \
  --verify \
  --private-key <PRIVATE_KEY>

# Deploy with custom salt suffix to avoid collisions
SALT_SUFFIX=prod_v1 forge script script/DeployUpgradeable.s.sol \
  --rpc-url <TESTNET_RPC_URL> \
  --broadcast \
  --verify \
  --private-key <PRIVATE_KEY>

# Deploy with timestamp salt for unique addresses
USE_TIMESTAMP_SALT=true forge script script/DeployUpgradeable.s.sol \
  --rpc-url <TESTNET_RPC_URL> \
  --broadcast \
  --verify \
  --private-key <PRIVATE_KEY>
```

### 1.1. Predict Addresses Before Deployment

Use the address prediction script to know contract addresses before deployment:

```bash
# Predict upgradeable contract addresses (default mode)
forge script script/PredictAddresses.s.sol

# Predict with custom salt suffix
SALT_SUFFIX=prod_v1 forge script script/PredictAddresses.s.sol

# Predict with timestamp salt
USE_TIMESTAMP_SALT=true forge script script/PredictAddresses.s.sol
```

### 2. Save Proxy Addresses

After deployment, save the proxy addresses from the output:
```
Proxy Addresses (Use these for interactions):
- CRA Registry:       0x...
- Consumption Record: 0x...
```

**Important:** Always use proxy addresses for contract interactions, not implementation addresses.

### 3. Set Environment Variables

Create a `.env` file with both proxy and implementation addresses:
```bash
# Proxy addresses (use these for interactions)
CRA_REGISTRY_ADDRESS=0x...
CONSUMPTION_RECORD_ADDRESS=0x...

# Implementation addresses (for upgrades)
CRA_REGISTRY_IMPL=0x...
CONSUMPTION_RECORD_IMPL=0x...

# Salt configuration (for consistent deployments)
SALT_SUFFIX=v1
# USE_TIMESTAMP_SALT=false  # Set to true for unique deployments
```

## Contract Upgrades

### 1. Modify Contract Logic

Update the implementation contracts:
- `src/cra_registry/CRARegistryUpgradeable.sol`
- `src/consumption_record/ConsumptionRecordUpgradeable.sol`

**Important**: Follow storage layout rules:
- Never remove existing state variables
- Only add new variables at the end
- Never change the type or order of existing variables

### 2. Test Upgrades

Run upgrade tests to ensure compatibility:
```bash
forge test --match-contract UpgradeWorkflowTest -v
```

### 3. Deploy New Implementations

Use the upgrade script to deploy new implementations and update proxies:

```bash
# Upgrade both contracts
CRA_REGISTRY_ADDRESS=0x... \
CONSUMPTION_RECORD_ADDRESS=0x... \
forge script script/UpgradeImplementations.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key <PRIVATE_KEY>

# Upgrade only CRA Registry
UPGRADE_CRA_REGISTRY=true \
UPGRADE_CONSUMPTION_RECORD=false \
CRA_REGISTRY_ADDRESS=0x... \
forge script script/UpgradeImplementations.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key <PRIVATE_KEY>
```

### 4. Verify Upgrades

After upgrade, verify:
- Proxy addresses remain the same
- All data is preserved
- New functionality works correctly

```bash
# Check contract version
cast call <PROXY_ADDRESS> "VERSION()" --rpc-url http://localhost:8545

# Verify data persistence
cast call <CRA_REGISTRY_ADDRESS> "getAllCras()" --rpc-url http://localhost:8545
```

## Best Practices

### Storage Layout

✅ **Safe Operations:**
```solidity
// Adding new variables at the end
contract V1 {
    uint256 public value1;
    string public name;
}

contract V2 {
    uint256 public value1;  // Same position
    string public name;     // Same position
    bool public newFlag;    // New variable at end
}
```

❌ **Unsafe Operations:**
```solidity
// DON'T: Change order or remove variables
contract V1 {
    uint256 public value1;
    string public name;
}

contract V2 {
    string public name;     // ❌ Changed order
    uint256 public value1;  // ❌ Changed order
}
```

### Upgrade Authorization

- Only contract owners can authorize upgrades
- Use multisig wallets for production deployments
- Consider timelocks for critical upgrades

### Testing Strategy

1. **Unit Tests**: Test new functionality
2. **Upgrade Tests**: Test upgrade process
3. **Integration Tests**: Test proxy + implementation interaction
4. **Fork Tests**: Test upgrades on fork of production

## Common Commands

### CREATE2 Address Management

```bash
# Predict addresses before deployment
forge script script/PredictAddresses.s.sol

# Predict with specific salt
SALT_SUFFIX=mainnet_v1 forge script script/PredictAddresses.s.sol

# Check if addresses are already deployed
forge script script/PredictAddresses.s.sol > predicted_addresses.txt
# Use the predicted addresses to check via cast code <address>
```

### Check Current Implementation

```bash
# Get implementation address from proxy (UUPS pattern)
cast call <PROXY_ADDRESS> "implementation()" --rpc-url <RPC_URL>

# For ERC1967 proxies, use the storage slot
cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <RPC_URL>
```

### Verify Proxy Setup

```bash
# Check if address is a proxy (should have bytecode)
cast code <ADDRESS> --rpc-url <RPC_URL>

# Verify proxy points to correct implementation
cast call <PROXY_ADDRESS> "implementation()" --rpc-url <RPC_URL>

# Check if CREATE2 deployed (compare with predicted address)
SALT_SUFFIX=v1 forge script script/PredictAddresses.s.sol | grep "Predicted address"
```

### CREATE2 Troubleshooting

```bash
# If deployment fails with CREATE2 collision
# Option 1: Use different salt
SALT_SUFFIX=v2 forge script script/DeployUpgradeable.s.sol --broadcast

# Option 2: Use timestamp for unique deployment
USE_TIMESTAMP_SALT=true forge script script/DeployUpgradeable.s.sol --broadcast

# Option 3: Check what's already deployed
cast code <PREDICTED_ADDRESS> --rpc-url <RPC_URL>
```

### Emergency Procedures

If an upgrade fails or causes issues:

1. **Check Upgrade Status**: Verify if upgrade completed
2. **Review Logs**: Check transaction logs for errors  
3. **Data Verification**: Confirm all data is intact
4. **Rollback Strategy**: Deploy previous implementation if needed

## CREATE2 Best Practices

### Salt Management Strategy

1. **Production Deployments**:
   - Use descriptive, consistent salt patterns: `mainnet_v1`, `testnet_v1`
   - Document salt values used for each network
   - Never reuse salts to prevent collisions

2. **Development/Testing**:
   - Use `USE_TIMESTAMP_SALT=true` for unique deployments
   - Use feature-specific salts: `feature_xyz_test`
   - Clean up test deployments regularly

3. **Multi-Chain Strategy**:
   - Use same salt across networks for consistent addresses
   - Verify predicted addresses match across chains
   - Test on testnets before mainnet deployment

### Environment Variable Management

Create network-specific `.env` files:

```bash
# .env.mainnet
SALT_SUFFIX=mainnet_v1
CRA_REGISTRY_ADDRESS=0x... (after deployment)
CONSUMPTION_RECORD_ADDRESS=0x... (after deployment)

# .env.testnet  
SALT_SUFFIX=testnet_v1
CRA_REGISTRY_ADDRESS=0x...
CONSUMPTION_RECORD_ADDRESS=0x...

# .env.local (for development)
USE_TIMESTAMP_SALT=true
# Addresses will be unique each deployment
```

### Deployment Checklist

1. **Pre-deployment**:
   - [ ] Run `PredictAddresses.s.sol` to get expected addresses
   - [ ] Verify addresses don't already exist: `cast code <address>`
   - [ ] Confirm salt suffix is appropriate for network
   - [ ] Test deployment on fork if mainnet

2. **Deployment**:
   - [ ] Deploy with appropriate environment variables
   - [ ] Verify all 4 contracts deploy successfully (2 implementations + 2 proxies)
   - [ ] Save all addresses to environment file
   - [ ] Verify contracts on block explorer

3. **Post-deployment**:
   - [ ] Test proxy → implementation delegation works
   - [ ] Verify ownership is correctly set
   - [ ] Test upgrade process on testnet first
   - [ ] Update client applications with proxy addresses

## Security Considerations

- **Test Thoroughly**: Always test upgrades on testnets first
- **Storage Layout**: Follow OpenZeppelin upgrade guidelines  
- **Access Control**: Secure upgrade authorization
- **Monitoring**: Monitor contracts after upgrades
- **Emergency Plans**: Have rollback procedures ready
- **CREATE2 Security**: Never expose private keys used for salt generation
- **Address Verification**: Always verify deployed addresses match predictions

## Support

For questions or issues:
- Check test examples in `test/upgrades/`
- Review OpenZeppelin upgrade documentation
- Contact: security@outbe.io