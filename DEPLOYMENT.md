# Deployment Guide

This guide covers deploying the Outbe L2 contracts (CRA Registry and Consumption Record) using Foundry.

## Quick Start

### Local Deployment (Anvil)

1. **Start Anvil:**
```bash
anvil
```

2. **Deploy contracts:**
```bash
# Full deployment with verification and logging
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast

# Quick deployment (minimal output)
forge script script/Deploy.s.sol:QuickDeployScript --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

1. **Set environment variables:**
```bash
export PRIVATE_KEY="0x..."
export RPC_URL="https://rpc.dev.outbe.net"
```

2. **Deploy:**
```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
```

## Deployment Scripts

### DeployScript (Full Featured)

The main deployment script with comprehensive logging and verification:

**Features:**
- ✅ Automatic deployer detection and balance checking
- ✅ Step-by-step deployment logging
- ✅ Post-deployment verification
- ✅ Contract linkage verification
- ✅ Network detection
- ✅ Optional initial CRA setup
- ✅ Environment variable summary
- ✅ Comprehensive error handling

**Usage:**
```bash
forge script script/Deploy.s.sol:DeployScript [OPTIONS]
```

### QuickDeployScript (Minimal)

Simplified deployment for quick testing:

**Features:**
- ✅ Fast deployment
- ✅ Minimal logging
- ✅ Essential contract addresses output

**Usage:**
```bash
forge script script/Deploy.s.sol:QuickDeployScript [OPTIONS]
```

## Environment Variables

### Required
- `PRIVATE_KEY` - Deployer private key (falls back to Anvil default for testing)

### Optional
- `RPC_URL` - RPC endpoint
- `SETUP_INITIAL_CRAS` - Set to `true` to register demo CRAs
- `INITIAL_CRA_1` - Address of first demo CRA
- `INITIAL_CRA_1_NAME` - Name of first demo CRA
- `INITIAL_CRA_2` - Address of second demo CRA
- `INITIAL_CRA_2_NAME` - Name of second demo CRA

### Example .env file:
```bash
# Required
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Network RPC URLs
RPC_URL=https://rpc.dev.outbe.net

# Optional: Demo CRA setup
SETUP_INITIAL_CRAS=true
INITIAL_CRA_1=0x1234567890123456789012345678901234567890
INITIAL_CRA_1_NAME="Demo Energy CRA"
INITIAL_CRA_2=0x2345678901234567890123456789012345678901
INITIAL_CRA_2_NAME="Demo Carbon CRA"

# Contract addresses (populated after deployment)
CRA_REGISTRY_ADDRESS=0x...
CONSUMPTION_RECORD_ADDRESS=0x...
```

## Common Deployment Commands

### Local Development
```bash
# Start local node
anvil

# Deploy to local node
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast

# Deploy with initial CRAs
SETUP_INITIAL_CRAS=true forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --broadcast
```

## Deployment Output

### Successful Deployment Example:
```
=== Outbe L2 Contracts Deployment ===
Deployer address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Chain ID: 11155111
Block number: 4562890

Deployer balance: 1 ETH

Deploying CRA Registry...
CRA Registry deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3
CRA Registry owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

Deploying Consumption Record...
Consumption Record deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Consumption Record owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Consumption Record CRA Registry: 0x5FbDB2315678afecb367f032d93F642f64180aa3

=== Deployment Verification ===
CRA Registry verification passed
Consumption Record verification passed
CRA Registry version: 0.0.1
Consumption Record version: 0.0.1

=== Deployment Summary ===
Network: outbe-dev-net-1
Deployment completed successfully!

Contract Addresses:
- CRA Registry:       0x5FbDB2315678afecb367f032d93F642f64180aa3
- Consumption Record: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

Environment Variables for .env:
CRA_REGISTRY_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
CONSUMPTION_RECORD_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

## Post-Deployment Steps

1. **Save contract addresses** in your `.env` file
2. **Verify contracts** on block explorer (automatic with `--verify` flag)
3. **Register initial CRAs** using the CRA Registry
4. **Update documentation** with deployed addresses
5. **Test contract interactions** using Cast or your frontend

## Testing Deployment

### Verify Contracts Work:
```bash
# Check CRA Registry
cast call $CRA_REGISTRY_ADDRESS "getAllCras()(address[])"
cast call $CRA_REGISTRY_ADDRESS "getOwner()(address)"

# Check Consumption Record
cast call $CONSUMPTION_RECORD_ADDRESS "getCraRegistry()(address)"
cast call $CONSUMPTION_RECORD_ADDRESS "getOwner()(address)"
```

### Register a Test CRA:
```bash
cast send $CRA_REGISTRY_ADDRESS "registerCra(address,string)" 0x1234567890123456789012345678901234567890 "Test CRA" --private-key $PRIVATE_KEY
```

### Check CRA Status:
```bash
cast call $CRA_REGISTRY_ADDRESS "isCraActive(address)(bool)" 0x1234567890123456789012345678901234567890
```

## Troubleshooting

### Common Issues:

**1. "Low balance" warning:**
- Ensure deployer has sufficient ETH for gas fees
- Use `--gas-estimate-multiplier 120` for higher gas price

**2. "Verification failed":**
- Check API key is correct
- Verify contract source matches exactly
- Try re-running verification separately

**3. "Private key not found":**
- Set `PRIVATE_KEY` environment variable
- For testing, script will use Anvil default key automatically

**4. "RPC connection failed":**
- Check RPC URL is correct and accessible
- Verify network is properly configured in foundry.toml

### Manual Contract Verification:
```bash
forge verify-contract \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address)" $CRA_REGISTRY_ADDRESS) \
  $CONSUMPTION_RECORD_ADDRESS \
  src/consumption_record/ConsumptionRecord.sol:ConsumptionRecord
```

## Security Considerations

1. **Private Key Management:**
   - Never commit private keys to version control
   - Use hardware wallets for mainnet deployments
   - Consider using `--interactives 1` flag for secure key input

2. **Verification:**
   - Always verify contracts on public networks
   - Double-check deployed addresses match expected values
   - Verify contract linkage is correct

3. **Testing:**
   - Test thoroughly on testnets before mainnet
   - Verify all functions work as expected post-deployment
   - Check access controls are properly configured

## Next Steps

After successful deployment:
1. Register CRAs using the registry
2. Update your frontend/backend with new contract addresses
3. Test the complete flow of CRA registration and consumption record submission
4. Set up monitoring and alerts for your contracts
5. Consider implementing upgradability patterns if needed for future versions