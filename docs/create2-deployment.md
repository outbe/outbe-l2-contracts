# CREATE2 Deployment Guide

## Overview

The Outbe L2 contracts use CREATE2 for deterministic deployment addresses across different networks. This ensures consistent contract addresses regardless of deployment order or network-specific conditions.

## What is CREATE2?

CREATE2 is an Ethereum opcode that allows deploying contracts to deterministic addresses. Unlike regular CREATE deployments (which use sender address + nonce), CREATE2 uses:
- Deployer address
- Salt (arbitrary bytes32)
- Contract bytecode hash

This produces the same address on any EVM-compatible chain.

## CREATE2 Factory

The deployment scripts use the standard CREATE2 factory at address:
```
0x4e59b44847b379578588920cA78FbF26c0B4956C
```

This is a widely-used deterministic deployment proxy maintained by the Ethereum community.

## Deployment Process

### Step 1: Check Factory Existence

First, verify if the CREATE2 factory exists on your target chain:

```bash
# Check if CREATE2 factory is deployed
cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <YOUR_RPC_URL>
```

If this returns `0x`, the factory is not deployed.

### Step 2: Deploy CREATE2 Factory (if needed)

If the factory doesn't exist, deploy it using the standard deployment transaction:

```bash
# Deploy CREATE2 factory
forge script script/DeployCREATE2Factory.s.sol --rpc-url <YOUR_RPC_URL> --broadcast --private-key <PRIVATE_KEY>
```

### Step 3: Deploy Your Contracts

Once the factory is available, deploy your upgradeable contracts:

```bash
# Deploy all contracts with deterministic addresses
forge script script/DeployUpgradeable.s.sol --rpc-url <YOUR_RPC_URL> --broadcast --private-key <PRIVATE_KEY>
```

## Alternative Deployment Methods

### Option 1: Deploy Without CREATE2

If CREATE2 deployment fails, use the alternative script:

```bash
forge script script/DeployWithoutCREATE2.s.sol --rpc-url <YOUR_RPC_URL> --broadcast --private-key <PRIVATE_KEY>
```

### Option 2: Custom CREATE2 Factory

Deploy your own CREATE2 factory and configure Foundry to use it:

```toml
# In foundry.toml
[profile.default]
create2_deployer = "YOUR_CUSTOM_FACTORY_ADDRESS"
```

### Option 3: Disable CREATE2

Temporarily disable CREATE2 for immediate deployment:

```toml
# In foundry.toml
[profile.default]
always_use_create_2_factory = false
```

## Deployment Scripts

### DeployCREATE2Factory.s.sol

This script deploys the standard CREATE2 factory using the canonical deployment method:

**Features:**
- Uses the official signed transaction
- Funds the one-time deployer account
- Verifies successful deployment
- Works on any EVM-compatible chain

**Usage:**
```bash
forge script script/DeployCREATE2Factory.s.sol \
  --rpc-url <YOUR_RPC_URL> \
  --broadcast \
  --private-key <PRIVATE_KEY>
```

### DeployUpgradeable.s.sol

The main deployment script with CREATE2 support:

**Features:**
- Deterministic contract addresses
- UUPS proxy pattern
- Salt-based address prediction
- Collision detection and prevention

**Configuration:**
```bash
# Use custom salt suffix
SALT_SUFFIX=production_v1 forge script script/DeployUpgradeable.s.sol --broadcast

# Use timestamp-based salt for testing
USE_TIMESTAMP_SALT=true forge script script/DeployUpgradeable.s.sol --broadcast
```

### DeployWithoutCREATE2.s.sol

Fallback deployment script without CREATE2:

**Features:**
- Regular CREATE deployment
- Same proxy pattern
- No deterministic addresses
- Immediate deployment capability

**Usage:**
```bash
forge script script/DeployWithoutCREATE2.s.sol \
  --rpc-url <YOUR_RPC_URL> \
  --broadcast \
  --private-key <PRIVATE_KEY>
```

## Salt Configuration

### Environment Variables

Control deployment addresses using salt configuration:

```bash
# Custom salt suffix
export SALT_SUFFIX="mainnet_v1"

# Timestamp-based salt (for unique addresses)
export USE_TIMESTAMP_SALT=true

# Initial CRA setup
export SETUP_INITIAL_CRAS=true
export INITIAL_CRA_1=0x1234567890123456789012345678901234567890
export INITIAL_CRA_1_NAME="Primary Energy CRA"
```

### Address Prediction

Predict contract addresses before deployment:

```bash
# Predict deployment addresses
forge script script/PredictAddresses.s.sol
```

## Troubleshooting

### Common Issues

1. **"missing CREATE2 deployer" Error**
   - Solution: Deploy the CREATE2 factory first
   - Command: `forge script script/DeployCREATE2Factory.s.sol --broadcast`

2. **"Contracts already deployed" Error**
   - Solution: Use different salt suffix
   - Command: `SALT_SUFFIX=new_version forge script ...`

3. **Gas Estimation Failures**
   - Solution: Use higher gas limits or different RPC endpoint
   - Command: Add `--gas-limit 10000000` to forge command

4. **Insufficient Balance**
   - Solution: Fund deployer account with more ETH
   - Check: `cast balance <DEPLOYER_ADDRESS> --rpc-url <RPC_URL>`

### Network-Specific Issues

#### Anvil (Local Testing)
```bash
# Start Anvil with CREATE2 factory
anvil --create2-deployer

# Or deploy manually after starting
forge script script/DeployCREATE2Factory.s.sol --rpc-url http://localhost:8545 --broadcast
```

#### Private Networks
```bash
# Fund the one-time deployer account first
cast send 0x3fab184622dc19b6109349b94811493bf2a45362 \
  --value 0.01ether \
  --rpc-url <YOUR_RPC_URL> \
  --private-key <PRIVATE_KEY>

# Then deploy the factory
forge script script/DeployCREATE2Factory.s.sol --broadcast
```

#### Public Testnets
Most public testnets already have the CREATE2 factory deployed. Verify with:
```bash
cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <TESTNET_RPC>
```

## Security Considerations

### Factory Verification
Always verify the CREATE2 factory bytecode matches the expected code:

```bash
# Get factory bytecode
cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <RPC_URL>

# Expected bytecode hash
# Should match: 0x604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3
```

### Salt Generation
- Use unpredictable salts for production deployments
- Avoid using sensitive data in salt generation
- Consider using commit-reveal schemes for competitive deployments

### Address Verification
Always verify deployed addresses match predictions:

```bash
# Predict addresses
forge script script/PredictAddresses.s.sol

# Deploy contracts
forge script script/DeployUpgradeable.s.sol --broadcast

# Verify addresses match predictions
```

## Best Practices

1. **Test Locally First**: Always test deployment on local Anvil before mainnet
2. **Verify Factory**: Check CREATE2 factory existence and bytecode
3. **Use Version Salts**: Include version numbers in salt for upgradeable deployments
4. **Document Addresses**: Save deployed addresses for frontend integration
5. **Monitor Gas Costs**: CREATE2 deployments may use more gas than regular CREATE
6. **Backup Plans**: Always have fallback deployment scripts without CREATE2

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Deploy Contracts
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      
      - name: Check CREATE2 Factory
        run: |
          if cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url ${{ secrets.RPC_URL }} | grep -q "0x"; then
            echo "CREATE2 factory exists"
          else
            echo "Deploying CREATE2 factory"
            forge script script/DeployCREATE2Factory.s.sol --broadcast --rpc-url ${{ secrets.RPC_URL }} --private-key ${{ secrets.PRIVATE_KEY }}
          fi
      
      - name: Deploy Contracts
        run: |
          forge script script/DeployUpgradeable.s.sol --broadcast --verify --rpc-url ${{ secrets.RPC_URL }} --private-key ${{ secrets.PRIVATE_KEY }}
        env:
          ETHERSCAN_API_KEY: ${{ secrets.ETHERSCAN_API_KEY }}
```

## Conclusion

CREATE2 deployment provides deterministic addresses across chains, essential for:
- Multi-chain protocol deployments
- Predictable contract interactions
- Cross-chain address consistency
- Upgradeable contract management

Follow this guide to ensure successful CREATE2 deployments of your Outbe L2 contracts.