# Outbe Contracts TypeScript Examples

This directory contains TypeScript examples demonstrating how to interact with the **upgradeable** Outbe L2 contracts using ethers.js and the UUPS proxy pattern.

## Overview

The examples cover:
- **CRARegistryUpgradeable**: Managing Consumption Reflection Agents with upgrade capabilities
- **ConsumptionRecordUpgradeable**: Storing consumption record hashes with metadata and upgrade capabilities
- **ConsumptionUnitUpgradeable**: Aggregating consumption records into settlement units with currency amounts
- **TributeDraftUpgradeable**: Minting tradeable tokens by aggregating consumption units
- **Proxy Pattern**: Working with upgradeable contracts via proxy addresses

## Files

- `cra-registry.ts` - CRA Registry client with full CRUD operations and upgrade functions
- `consumption-record.ts` - Consumption Record client with metadata handling and upgrade functions
- `consumption-unit.ts` - Consumption Unit client with settlement amount handling and batch operations
- `tribute-draft.ts` - Tribute Draft client with aggregation validation and minting functionality
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
import { ConsumptionUnitClient, ConsumptionUnitBuilder } from './consumption-unit';
import { TributeDraftClient, TributeDraftBuilder } from './tribute-draft';

// Setup provider and wallets
const provider = new ethers.JsonRpcProvider('http://localhost:8545');
const ownerWallet = new Wallet('0x...owner-key', provider);
const craWallet = new Wallet('0x...cra-key', provider);
const userWallet = new Wallet('0x...user-key', provider);

// IMPORTANT: Use proxy addresses, not implementation addresses!
const registryProxyAddress = '0x...cra-registry-proxy';
const recordProxyAddress = '0x...consumption-record-proxy';
const unitProxyAddress = '0x...consumption-unit-proxy';
const draftProxyAddress = '0x...tribute-draft-proxy';

// Initialize clients with proxy addresses
const registry = new CRARegistryClient(registryProxyAddress, ownerWallet, provider);
const records = new ConsumptionRecordClient(recordProxyAddress, craWallet, provider);
const units = new ConsumptionUnitClient(unitProxyAddress, craWallet, provider);
const drafts = new TributeDraftClient(draftProxyAddress, userWallet, provider);

// 1. Register a CRA
await registry.registerCra(craWallet.address, 'My Energy CRA');

// 2. Submit consumption records
const metadata = new ConsumptionMetadataBuilder()
  .setSource('solar')
  .setAmount('150.5')
  .setUnit('kWh')
  .build();

const crHash = ConsumptionRecordClient.generateHash({deviceId: 'meter-001'});
await records.submit(crHash, userWallet.address, metadata);

// 3. Create consumption unit from records
const cuParams = new ConsumptionUnitBuilder()
  .setCuHash('0x1234...')
  .setOwner(userWallet.address)
  .setSettlementCurrency('USD')
  .setWorldwideDay('2024-01-15')
  .setSettlementAmountFromDecimal('150.75')
  .setNominalQuantityFromDecimal('100.5')
  .setNominalCurrency('kWh')
  .addConsumptionRecordHash(crHash)
  .build();

await units.submit(cuParams);

// 4. Mint tribute draft from consumption units
const mintParams = new TributeDraftBuilder()
  .addConsumptionUnit(cuParams.cuHash)
  .build();

const result = await drafts.mint(mintParams);
console.log('Tribute draft minted:', result.tributeDraftId);

// Upgrade contract (owner only)
// await registry.upgradeTo('0x...new-implementation');
```

## Contract Addresses

Update these addresses in your code:

```typescript
const CRA_REGISTRY_ADDRESS = '0x...';
const CONSUMPTION_RECORD_ADDRESS = '0x...';
const CONSUMPTION_UNIT_ADDRESS = '0x...';
const TRIBUTE_DRAFT_ADDRESS = '0x...';
```

## Environment Setup

### Local Development (Anvil)

```bash
# Start local Ethereum node
anvil

# Deploy contracts (in separate terminal)
forge script script/DeployUpgradeable.s.sol --broadcast --rpc-url http://localhost:8545
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

// Consumption unit events
units.onSubmitted((cuHash, cra, timestamp) => {
  console.log(`New consumption unit: ${cuHash} from CRA: ${cra}`);
});

// Tribute draft events
drafts.onMinted((tributeDraftId, owner, submittedBy, cuCount, timestamp) => {
  console.log(`New tribute draft: ${tributeDraftId} (${cuCount} CUs) by ${owner}`);
});
```

## Builder Patterns

### Consumption Record Metadata Builder

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

### Consumption Unit Builder

Build consumption units with settlement amounts and quantities:

```typescript
const cuParams = new ConsumptionUnitBuilder()
  .setCuHash('0x1234567890123456789012345678901234567890123456789012345678901234')
  .setOwner('0x...owner-address')
  .setSettlementCurrency('USD')
  .setWorldwideDay('2024-01-15')
  .setSettlementAmountFromDecimal('150.75')  // $150.75
  .setNominalQuantityFromDecimal('100.5')    // 100.5 kWh
  .setNominalCurrency('kWh')
  .addConsumptionRecordHash('0xabcd...')
  .build();
```

### Tribute Draft Builder

Build tribute drafts from multiple consumption units:

```typescript
const mintParams = new TributeDraftBuilder()
  .addConsumptionUnit('0x1111111111111111111111111111111111111111111111111111111111111111')
  .addConsumptionUnit('0x2222222222222222222222222222222222222222222222222222222222222222')
  .addConsumptionUnit('0x3333333333333333333333333333333333333333333333333333333333333333')
  .build();

// Or use array method
const mintParams = new TributeDraftBuilder()
  .setConsumptionUnits([
    '0x1111111111111111111111111111111111111111111111111111111111111111',
    '0x2222222222222222222222222222222222222222222222222222222222222222'
  ])
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

// Test consumption unit validation
const cuExists = await units.isExists(cuHash);
if (cuExists) {
  throw new Error('Consumption unit already exists');
}

// Test tribute draft aggregation validation
import { TributeDraftAggregator } from './tribute-draft';

const consumptionUnits = [
  { owner: userAddress, settlementCurrency: 'USD', worldwideDay: '2024-01-15' },
  { owner: userAddress, settlementCurrency: 'USD', worldwideDay: '2024-01-15' }
];

const validation = TributeDraftAggregator.validateAggregation(consumptionUnits, userAddress);
if (!validation.valid) {
  throw new Error(`Aggregation validation failed: ${validation.error}`);
}
```

## Contributing

When adding new examples:
1. Follow the existing code structure
2. Include comprehensive error handling
3. Add JSDoc comments for public methods
4. Include usage examples in comments
5. Test with both success and failure scenarios

## Advanced Features

### Batch Processing with Retry Logic

The examples include advanced batch processing utilities:

```typescript
import { BatchConsumptionProcessor } from './consumption-record';

const processor = new BatchConsumptionProcessor(records);

const result = await processor.processBatch([
  { hash: '0x...', owner: '0x...', metadata: {...} },
  // ... more records
], true); // Enable retry for failures

console.log(`✅ Successful: ${result.successful.length}`);
console.log(`❌ Failed: ${result.failed.length}`);
```

### Analytics and Reporting

Generate comprehensive consumption analytics:

```typescript
import { ConsumptionAnalytics } from './consumption-record';

const analytics = new ConsumptionAnalytics(recordsClient);
const analysis = await analytics.analyzeOwnerConsumption(ownerAddress);

console.log(`Total consumption: ${analysis.totalAmount} units`);
console.log(`Energy sources:`, analysis.energySources);

// Generate markdown report
const report = await analytics.generateReport(ownerAddress);
```

### Real-time Monitoring

Set up real-time monitoring services:

```typescript
import { ConsumptionMonitor } from './consumption-record';
import { CRAMonitoringService } from './cra-registry';

// Monitor consumption records
const consumptionMonitor = new ConsumptionMonitor(recordsClient);
consumptionMonitor.startMonitoring(['0xOwner1...', '0xOwner2...']);

consumptionMonitor.on('newRecord', (data) => {
  console.log(`New record from ${data.owner}: ${data.metadata.amount}`);
});

// Monitor CRA system health
const craMonitor = new CRAMonitoringService(registryAddress, provider);
craMonitor.startMonitoring();

const systemStatus = await craMonitor.getSystemStatus();
console.log(`Active CRAs: ${systemStatus.statusBreakdown.Active || 0}`);
```

### Health Checking

Implement health checking for system components:

```typescript
import { CRAHealthChecker } from './cra-registry';

const healthChecker = new CRAHealthChecker(registryAddress, provider);

// Check individual CRA health
const health = await healthChecker.checkCRAHealth('0xCRA...');
if (!health.isHealthy) {
  console.log('Issues found:', health.issues);
}

// Check all CRAs
const systemHealth = await healthChecker.checkAllCRAHealth();
console.log(`${systemHealth.healthyCras}/${systemHealth.totalCras} CRAs healthy`);
```

### Complex Workflows

Example of a complete energy trading workflow:

```typescript
import { ConsumptionUnitClient, ConsumptionUnitBuilder } from './consumption-unit';
import { TributeDraftClient, TributeDraftBuilder } from './tribute-draft';
import { TributeDraftAggregator } from './tribute-draft';

// 1. Create consumption units from records
const cuBuilder = new ConsumptionUnitBuilder()
  .setCuHash('0x1234...')
  .setOwner(userAddress)
  .setSettlementCurrency('USD')
  .setWorldwideDay('2024-01-15')
  .setSettlementAmountFromDecimal('150.75')
  .setNominalQuantityFromDecimal('100.5')
  .setNominalCurrency('kWh')
  .addConsumptionRecordHash('0xabcd...');

const cuParams = cuBuilder.build();
await cuClient.submit(cuParams);

// 2. Validate aggregation before minting
const consumptionUnits = [
  { owner: userAddress, settlementCurrency: 'USD', worldwideDay: '2024-01-15' },
  { owner: userAddress, settlementCurrency: 'USD', worldwideDay: '2024-01-15' }
];

const validation = TributeDraftAggregator.validateAggregation(consumptionUnits, userAddress);
if (!validation.valid) {
  throw new Error(`Cannot aggregate: ${validation.error}`);
}

// 3. Calculate total settlement amount
const total = TributeDraftAggregator.calculateTotalSettlement([
  { settlementBaseAmount: 100n, settlementAttoAmount: 500000000000000000n },
  { settlementBaseAmount: 50n, settlementAttoAmount: 250000000000000000n }
]);

console.log(`Total: ${TributeDraftClient.formatAmount(total.base, total.atto)} USD`);

// 4. Mint tribute draft
const mintParams = new TributeDraftBuilder()
  .addConsumptionUnit(cuParams.cuHash)
  .build();

const result = await tributeDraftClient.mint(mintParams);
console.log(`Minted tribute draft: ${result.tributeDraftId}`);
```

### Error Handling Best Practices

The examples demonstrate comprehensive error handling:

```typescript
try {
  // Contract interaction
  await registry.registerCra(craAddress, name);
} catch (error: any) {
  // Parse contract-specific errors
  if (error.reason) {
    switch (error.reason) {
      case 'CRAAlreadyRegistered()':
        console.log('CRA already exists');
        break;
      case 'UnauthorizedAccess()':
        console.log('Access denied - owner required');
        break;
      default:
        console.log('Contract error:', error.reason);
    }
  } else if (error.code === 'CALL_EXCEPTION') {
    console.log('Contract call failed:', error.message);
  } else {
    console.log('Unexpected error:', error);
  }
}
```

### Performance Optimization

Tips for optimizing performance:

1. **Batch Operations**: Use batch functions when submitting multiple records
2. **Event Filtering**: Filter events by indexed parameters to reduce data transfer
3. **Pagination**: Implement pagination for large data sets
4. **Caching**: Cache frequently accessed data like CRA status
5. **Connection Pooling**: Reuse provider connections when possible

```typescript
// Example: Efficient batch processing with pagination
async function processLargeDataset(records: any[], batchSize: number = 100) {
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    
    try {
      await submitBatch(batch);
      console.log(`✅ Processed batch ${Math.floor(i / batchSize) + 1}`);
    } catch (error) {
      console.error(`❌ Batch ${Math.floor(i / batchSize) + 1} failed:`, error);
      // Implement fallback or retry logic
    }
    
    // Add delay to prevent rate limiting
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}
```