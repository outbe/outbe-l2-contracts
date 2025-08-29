# Outbe Contracts TypeScript Examples

This directory contains TypeScript examples demonstrating how to interact with the Outbe L2 contracts using ethers.js.

## Overview

The examples cover:
- **CRA Registry**: Managing Consumption Reflection Agents
- **Consumption Record**: Storing consumption record hashes with metadata

## Files

- `cra-registry.ts` - CRA Registry client with full CRUD operations
- `consumption-record.ts` - Consumption Record client with metadata handling
- `package.json` - Node.js dependencies
- `tsconfig.json` - TypeScript configuration

## Installation

```bash
cd examples
npm install
```

## Usage

### Quick Start

```typescript
import { ethers } from 'ethers';
import { CRARegistryClient, CRAStatus } from './cra-registry';
import { ConsumptionRecordClient, ConsumptionMetadataBuilder } from './consumption-record';

// Setup provider and wallets
const provider = new ethers.JsonRpcProvider('http://localhost:8545');
const ownerWallet = new Wallet('0x...owner-key', provider);
const craWallet = new Wallet('0x...cra-key', provider);

// Initialize clients
const registry = new CRARegistryClient(registryAddress, ownerWallet, provider);
const records = new ConsumptionRecordClient(recordAddress, craWallet, provider);

// Register a CRA
await registry.registerCra(craWallet.address, 'My Energy CRA');

// Submit a consumption record
const metadata = new ConsumptionMetadataBuilder()
  .setSource('solar')
  .setAmount('150.5')
  .setUnit('kWh')
  .build();

const hash = ConsumptionRecordClient.generateHash({deviceId: 'meter-001'});
await records.submit(hash, metadata);
```

## Contract Addresses

Update these addresses in your code:

```typescript
const CRA_REGISTRY_ADDRESS = '0x...';
const CONSUMPTION_RECORD_ADDRESS = '0x...';
```

## Environment Setup

### Local Development (Anvil)

```bash
# Start local Ethereum node
anvil

# Deploy contracts (in separate terminal)
forge script script/Deploy.s.sol --broadcast --rpc-url http://localhost:8545
```

### Testnet Deployment

```bash
# Set environment variables
export RPC_URL="https://rpc.dev.outbe.net"
export PRIVATE_KEY="0x..."

# Update contract addresses in examples
```

## Error Handling

The clients provide typed error handling:

```typescript
try {
  await registry.registerCra(address, name);
} catch (error) {
  if (error.message.includes('CRAAlreadyRegistered')) {
    console.log('CRA is already registered');
  } else if (error.message.includes('UnauthorizedAccess')) {
    console.log('Only owner can register CRAs');
  }
}
```

## Event Monitoring

Set up event listeners for real-time monitoring:

```typescript
// CRA events
registry.onCRARegistered((cra, name, timestamp) => {
  console.log(`New CRA: ${name} at ${cra}`);
});

// Consumption record events
records.onSubmitted((hash, cra, timestamp) => {
  console.log(`New record: ${hash} from ${cra}`);
});
```

## Metadata Builder

Use the fluent API for building consumption metadata:

```typescript
const metadata = new ConsumptionMetadataBuilder()
  .setSource('renewable')
  .setAmount('100.5')
  .setUnit('kWh')
  .setLocation('San Francisco, CA')
  .setRenewablePercentage('85')
  .setCarbonFootprint('0.12')
  .setCustom('device_id', 'smart-meter-001')
  .setCustom('utility', 'PG&E')
  .build();
```

## Security Considerations

1. **Private Keys**: Never commit private keys to version control
2. **Access Control**: Only authorized addresses can perform admin operations
3. **Hash Validation**: Always validate consumption record hashes
4. **Error Handling**: Implement proper error handling for all operations
5. **Event Monitoring**: Monitor events for security and audit purposes

## Testing

The examples include error cases and edge condition handling:

```typescript
// Test CRA status validation
const isActive = await registry.isCraActive(craAddress);
if (!isActive) {
  throw new Error('CRA must be active to submit records');
}

// Test hash uniqueness
const exists = await records.isExists(hash);
if (exists) {
  throw new Error('Record already exists');
}
```

## Contributing

When adding new examples:
1. Follow the existing code structure
2. Include comprehensive error handling
3. Add JSDoc comments for public methods
4. Include usage examples in comments
5. Test with both success and failure scenarios