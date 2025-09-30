/**
 * Test Script: Create Consumption Records (CR) for thousands of users
 *
 * This script generates and submits consumption records for testing network scalability.
 * It creates thousands of CRs for multiple users using batch submission.
 *
 * Usage: ts-node create-consumption-records.ts
 */

import { ethers, Wallet } from 'ethers';
import { config } from 'dotenv';
import { resolve } from 'path';
import {
  ConsumptionRecordClient,
  ConsumptionMetadataBuilder,
  BatchSubmissionRequest
} from '../lib/consumption-record';
import { CRARegistryClient } from '../lib/cra-registry';
import { createActiveCRA } from './create-active-cra';

// Load environment variables from examples/.env
config({ path: resolve(__dirname, '../.env') });

// Configuration
const CONFIG = {
  // Network settings
  RPC_URL: process.env.RPC_URL! ,
  PRIVATE_KEY: process.env.OWNER_PRIVATE_KEY!,
  CONSUMPTION_RECORD_PROXY: process.env.CONSUMPTION_RECORD_PROXY! ,
  CRA_REGISTRY_PROXY: process.env.CRA_REGISTRY_PROXY! ,

  // Test parameters
  RECORDS_PER_USER: parseInt(process.env.RECORDS_PER_USER! ),
  BATCH_SIZE: parseInt(process.env.BATCH_SIZE! ), // Max is typically 100

  // Input file
  USERS_FILE: './results/generated-users.json',

  // Energy sources for realistic data
  ENERGY_SOURCES: ['solar', 'wind', 'hydro', 'geothermal', 'biomass'],
  ENERGY_UNITS: ['kWh', 'MWh', 'GWh'],
};

/**
 * Load users from the generated users file
 */
async function loadUsers(): Promise<Array<{ address: string; privateKey: string }>> {
  const fs = await import('fs');
  const path = await import('path');

  const filePath = path.resolve(__dirname, CONFIG.USERS_FILE);

  if (!fs.existsSync(filePath)) {
    throw new Error(`Users file not found: ${filePath}\nPlease run generate-users.ts first.`);
  }

  const data = fs.readFileSync(filePath, 'utf-8');
  const parsed = JSON.parse(data);
  return parsed.users;
}

/**
 * Generate random consumption data
 */
function generateConsumptionData(userIndex: number, recordIndex: number) {
  const timestamp = Date.now() - (recordIndex * 3600000); // 1 hour intervals
  const deviceId = `device-${userIndex}-${recordIndex}`;
  const amount = Math.random() * 1000 + 100; // 100-1100 kWh
  const source = CONFIG.ENERGY_SOURCES[Math.floor(Math.random() * CONFIG.ENERGY_SOURCES.length)];

  return {
    deviceId,
    timestamp,
    amount,
    source,
    userIndex,
    recordIndex
  };
}

/**
 * Generate a batch of consumption records
 */
async function generateBatchRecords(
  users: Array<{ address: string; privateKey: string }>,
  startUserIndex: number,
  endUserIndex: number,
  recordsPerUser: number
): Promise<BatchSubmissionRequest[]> {
  const records: BatchSubmissionRequest[] = [];

  for (let userIdx = startUserIndex; userIdx < endUserIndex; userIdx++) {
    const ownerAddress = users[userIdx].address;

    for (let recIdx = 0; recIdx < recordsPerUser; recIdx++) {
      const consumptionData = generateConsumptionData(userIdx, recIdx);

      // Generate unique hash for this consumption record
      const crHash = ConsumptionRecordClient.generateHash({
        ...consumptionData,
        owner: ownerAddress
      });

      // Build metadata
      const metadata = new ConsumptionMetadataBuilder()
        .setSource(consumptionData.source)
        .setAmount(consumptionData.amount.toFixed(2))
        .setUnit('kWh')
        .setTimestamp(consumptionData.timestamp)
        .setLocation(`Location-${userIdx}`)
        .setRenewablePercentage((Math.random() * 100).toFixed(1))
        .setCarbonFootprint((Math.random() * 0.5).toFixed(3))
        .setCustom('device_id', consumptionData.deviceId)
        .setCustom('user_index', userIdx.toString())
        .setCustom('record_index', recIdx.toString())
        .build();

      records.push({
        crHash,
        owner: ownerAddress,
        metadata
      });
    }
  }

  return records;
}

/**
 * Submit records in batches
 */
async function submitRecordsInBatches(
  client: ConsumptionRecordClient,
  records: BatchSubmissionRequest[]
): Promise<{
  successful: number;
  failed: number;
  totalBatches: number;
  results: string[];
}> {
  const results: string[] = [];
  let successful = 0;
  let failed = 0;

  // Split into batches
  const batches: BatchSubmissionRequest[][] = [];
  for (let i = 0; i < records.length; i += CONFIG.BATCH_SIZE) {
    batches.push(records.slice(i, i + CONFIG.BATCH_SIZE));
  }

  console.log(`\n📦 Submitting ${records.length} records in ${batches.length} batches...`);

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    const batchNum = i + 1;

    try {
      console.log(`\n⏳ Processing batch ${batchNum}/${batches.length} (${batch.length} records)...`);

      const startTime = Date.now();
      const result = await client.submitBatch(batch);
      const duration = Date.now() - startTime;

      successful += batch.length;
      results.push(`Batch ${batchNum}: ✅ ${batch.length} records in ${duration}ms (tx: ${result.transactionHash})`);
      console.log(`✅ Batch ${batchNum} completed in ${duration}ms`);

      // Small delay to avoid overwhelming the network
      if (i < batches.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }

    } catch (error: any) {
      failed += batch.length;
      const errorMsg = error.message || String(error);
      results.push(`Batch ${batchNum}: ❌ Failed - ${errorMsg}`);
      console.error(`❌ Batch ${batchNum} failed:`, errorMsg);

      // Continue with next batch even if this one fails
      continue;
    }
  }

  return {
    successful,
    failed,
    totalBatches: batches.length,
    results
  };
}

/**
 * Save generated CR hashes to file for later use
 */
async function saveCRHashesForUsers(records: BatchSubmissionRequest[]): Promise<void> {
  const fs = await import('fs');
  const path = await import('path');

  // Group by user
  const userRecords = new Map<string, string[]>();

  for (const record of records) {
    if (!userRecords.has(record.owner)) {
      userRecords.set(record.owner, []);
    }
    userRecords.get(record.owner)!.push(record.crHash);
  }

  // Save to JSON file
  const outputData = {
    generatedAt: new Date().toISOString(),
    totalUsers: userRecords.size,
    totalRecords: records.length,
    users: Array.from(userRecords.entries()).map(([owner, hashes]) => ({
      owner,
      crHashes: hashes
    }))
  };

  const outputPath = path.join(__dirname, 'results/generated-cr-hashes.json');
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));

  console.log(`\n💾 Saved CR hashes to: ${outputPath}`);
}


/**
 * Main execution function
 */
async function main() {
  console.log('🚀 Starting Consumption Record Generation Test\n');

  // Load users
  console.log('📂 Loading users...');
  const users = await loadUsers();
  console.log(`✅ Loaded ${users.length} users`);

  console.log('\nConfiguration:');
  console.log(`  - Total Users: ${users.length}`);
  console.log(`  - Records per User: ${CONFIG.RECORDS_PER_USER}`);
  console.log(`  - Total Records: ${users.length * CONFIG.RECORDS_PER_USER}`);
  console.log(`  - Batch Size: ${CONFIG.BATCH_SIZE}`);
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);

  if (!CONFIG.CONSUMPTION_RECORD_PROXY) {
    throw new Error('CONSUMPTION_RECORD_PROXY environment variable is required');
  }

  if (!CONFIG.CRA_REGISTRY_PROXY) {
    throw new Error('CRA_REGISTRY_PROXY environment variable is required');
  }

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  const craWallet = new Wallet(CONFIG.PRIVATE_KEY, provider);

  console.log(`\n🔑 CRA Address: ${craWallet.address}`);
  console.log(`📝 Contract Address: ${CONFIG.CONSUMPTION_RECORD_PROXY}`);
  console.log(`📝 CRA Registry Address: ${CONFIG.CRA_REGISTRY_PROXY}`);

  // Initialize CRA Registry client
  const craRegistryClient = new CRARegistryClient(
    CONFIG.CRA_REGISTRY_PROXY,
    craWallet,
    provider
  );

  // Ensure CRA is registered and active
  await createActiveCRA(craRegistryClient, craWallet.address, 'Test CRA for Consumption Records');

  // Initialize client
  const crClient = new ConsumptionRecordClient(
    CONFIG.CONSUMPTION_RECORD_PROXY,
    craWallet,
    provider
  );

  // Generate all records
  console.log('\n📋 Generating consumption records...');
  const startGenTime = Date.now();
  const allRecords = await generateBatchRecords(
    users,
    0,
    users.length,
    CONFIG.RECORDS_PER_USER
  );
  const genDuration = Date.now() - startGenTime;
  console.log(`✅ Generated ${allRecords.length} records in ${genDuration}ms`);

  // Save CR hashes for later use (CU and TD creation)
  await saveCRHashesForUsers(allRecords);

  // Submit records
  const startSubmitTime = Date.now();
  const submissionResult = await submitRecordsInBatches(crClient, allRecords);
  const submitDuration = Date.now() - startSubmitTime;

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUBMISSION SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total Records: ${allRecords.length}`);
  console.log(`Successful: ${submissionResult.successful} ✅`);
  console.log(`Failed: ${submissionResult.failed} ❌`);
  console.log(`Total Batches: ${submissionResult.totalBatches}`);
  console.log(`Total Duration: ${submitDuration}ms (${(submitDuration / 1000).toFixed(2)}s)`);
  console.log(`Average per Record: ${(submitDuration / allRecords.length).toFixed(2)}ms`);
  console.log(`Average per Batch: ${(submitDuration / submissionResult.totalBatches).toFixed(2)}ms`);
  console.log('='.repeat(60));

  // Show batch results
  if (submissionResult.results.length <= 20) {
    console.log('\n📋 Batch Results:');
    submissionResult.results.forEach(result => console.log(`  ${result}`));
  }


  // Return data for potential chaining
  return {
    totalUsers: users.length,
    totalRecords: allRecords.length,
    successful: submissionResult.successful,
    failed: submissionResult.failed,
    records: allRecords
  };
}

// Execute if run directly
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('\n❌ Error:', error);
      process.exit(1);
    });
}

export { main, loadUsers, generateBatchRecords };
