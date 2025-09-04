# CREATE2 Deterministic Deployments

This project uses Foundry's built-in CREATE2 support for deterministic contract deployments.

## Configuration

The `foundry.toml` is configured with:
```toml
always_use_create_2_factory = true
bytecode_hash = "none"
cbor_metadata = false
```

## Usage

### 1. Predict Addresses
Before deployment, predict contract addresses:
```bash
forge script script/PredictAddresses.s.sol
```

### 2. Deploy Contracts
Deploy with deterministic addresses:
```bash
# Local deployment
forge script script/Deploy.s.sol --broadcast

# Testnet deployment
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### 3. Quick Deploy (Testing)
For quick testing:
```bash
forge script script/Deploy.s.sol:QuickDeploy --broadcast
```

## How It Works

With `always_use_create_2_factory = true`, Foundry automatically:
1. Uses CREATE2 for all contract deployments
2. Generates deterministic addresses based on salt and bytecode
3. Ensures same addresses across different networks

## Salt Values

Current salt values used:
- CRARegistry: `"CRARegistry_v1"`
- ConsumptionRecord: `"ConsumptionRecord_v1"`

Change salt values in deployment scripts to deploy new versions.

## Environment Variables

```bash
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_etherscan_key  # For verification
```