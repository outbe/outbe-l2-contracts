/**
 * Test Script: Create Consumption Units (CU) from Consumption Records
 *
 * This script generates and submits consumption units for testing network scalability.
 * It aggregates previously created CRs into CUs for thousands of users.
 *
 * Usage: ts-node create-consumption-units.ts
 */

import { ethers, Wallet } from 'ethers';
import { config } from 'dotenv';
import { resolve } from 'path';
import {
  ConsumptionUnitClient,
  ConsumptionUnitBuilder,
  ConsumptionUnitParams
} from '../lib/consumption-unit';

// Load environment variables from examples/.env
config({ path: resolve(__dirname, '../.env') });
// Configuration
const CONFIG = {
  // Network settings
  RPC_URL: process.env.RPC_URL! ,
  PRIVATE_KEY: process.env.OWNER_PRIVATE_KEY! ,
  CONSUMPTION_UNIT_PROXY: process.env.CONSUMPTION_UNIT_PROXY! ,

  // Test parameters
  BATCH_SIZE: parseInt(process.env.BATCH_SIZE!), // CUs per batch (max 100)

  // Input file from previous step
  CR_HASHES_FILE: './results/generated-cr-hashes.json',

  // Settlement parameters (ISO 4217 numeric codes)
  SETTLEMENT_CURRENCIES: [840, 978, 826], // USD, EUR, GBP
};

/**
 * Load CR hashes from the previous script
 */
async function loadCRHashes(): Promise<{
  totalUsers: number;
  totalRecords: number;
  users: Array<{ owner: string; crHashes: string[] }>;
}> {
  const fs = await import('fs');
  const path = await import('path');

  const filePath = path.resolve(__dirname, CONFIG.CR_HASHES_FILE);

  if (!fs.existsSync(filePath)) {
    throw new Error(`CR hashes file not found: ${filePath}\nPlease run create-consumption-records.ts first.`);
  }

  const data = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(data);
}

/**
 * Generate a CU from a group of CR hashes
 */
function generateConsumptionUnit(
  owner: string,
  crHashes: string[],
  userIndex: number,
  cuIndex: number
): ConsumptionUnitParams {
  // Generate deterministic worldwide day in YYYYMMDD format
  const date = new Date();
  date.setDate(date.getDate() - cuIndex); // Different day for each CU
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const worldwideDay = parseInt(`${year}${month}${day}`); // e.g., 20240115

  // Random settlement currency (ISO 4217 numeric code)
  const settlementCurrency = CONFIG.SETTLEMENT_CURRENCIES[userIndex % CONFIG.SETTLEMENT_CURRENCIES.length];

  // Calculate amounts based on number of CRs
  const baseAmount = BigInt(Math.floor(crHashes.length * 100 + Math.random() * 50)); // $100-150 per CR
  const attoAmount = BigInt(Math.floor(Math.random() * 1e17)); // Random fractional part

  // Generate settlement data for hash calculation
  const settlementData = `${settlementCurrency}-${baseAmount}-${attoAmount}`;

  // Generate CU hash
  const cuHash = ConsumptionUnitClient.generateHash({
    owner,
    settlementData,
    worldwideDay: worldwideDay.toString(),
    consumptionRecordHashes: crHashes
  });

  // Build CU parameters
  return new ConsumptionUnitBuilder()
    .setCuHash(cuHash)
    .setOwner(owner)
    .setSettlementCurrency(settlementCurrency)
    .setWorldwideDay(worldwideDay)
    .setSettlementAmount(baseAmount, attoAmount)
    .setConsumptionRecordHashes(crHashes)
    .build();
}

/**
 * Generate all CUs from CR hashes
 */
function generateAllConsumptionUnits(
  crData: { totalUsers: number; totalRecords: number; users: Array<{ owner: string; crHashes: string[] }> }
): ConsumptionUnitParams[] {
  const consumptionUnits: ConsumptionUnitParams[] = [];

  for (let userIndex = 0; userIndex < crData.users.length; userIndex++) {
    const user = crData.users[userIndex];

    // Create one CU aggregating all CRs for this user
    if (user.crHashes.length > 0) {
      const cu = generateConsumptionUnit(
        user.owner,
        user.crHashes,
        userIndex,
        0
      );
      consumptionUnits.push(cu);
    }
  }

  return consumptionUnits;
}

/**
 * Submit CUs in batches
 */
async function submitCUsInBatches(
  client: ConsumptionUnitClient,
  consumptionUnits: ConsumptionUnitParams[]
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
  const batches: ConsumptionUnitParams[][] = [];
  for (let i = 0; i < consumptionUnits.length; i += CONFIG.BATCH_SIZE) {
    batches.push(consumptionUnits.slice(i, i + CONFIG.BATCH_SIZE));
  }

  console.log(`\n📦 Submitting ${consumptionUnits.length} CUs in ${batches.length} batches...`);

  for (let i = 0; i < batches.length; i++) {
    const batch = batches[i];
    const batchNum = i + 1;

    try {
      console.log(`\n⏳ Processing batch ${batchNum}/${batches.length} (${batch.length} CUs)...`);

      const startTime = Date.now();
      const txHash = await client.submitBatch(batch);
      const duration = Date.now() - startTime;

      successful += batch.length;
      results.push(`Batch ${batchNum}: ✅ ${batch.length} CUs in ${duration}ms (tx: ${txHash})`);
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

      // Continue with next batch
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
 * Save generated CU hashes to file for later use (Tribute Drafts)
 */
async function saveCUHashesForUsers(consumptionUnits: ConsumptionUnitParams[]): Promise<void> {
  const fs = await import('fs');
  const path = await import('path');

  // Group by user
  const userCUs = new Map<string, Array<{
    cuHash: string;
    worldwideDay: number;
    settlementCurrency: number;
    crCount: number;
  }>>();

  for (const cu of consumptionUnits) {
    if (!userCUs.has(cu.owner)) {
      userCUs.set(cu.owner, []);
    }
    userCUs.get(cu.owner)!.push({
      cuHash: cu.cuHash,
      worldwideDay: cu.worldwideDay,
      settlementCurrency: cu.settlementCurrency,
      crCount: cu.consumptionRecordHashes.length
    });
  }

  // Save to JSON file
  const outputData = {
    generatedAt: new Date().toISOString(),
    totalUsers: userCUs.size,
    totalCUs: consumptionUnits.length,
    users: Array.from(userCUs.entries()).map(([owner, cus]) => ({
      owner,
      totalCUs: cus.length,
      consumptionUnits: cus
    }))
  };

  const outputPath = path.join(__dirname, 'results/generated-cu-hashes.json');
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));

  console.log(`\n💾 Saved CU hashes to: ${outputPath}`);
}

/**
 * Main execution function
 */
async function main() {
  console.log('🚀 Starting Consumption Unit Generation Test\n');

  if (!CONFIG.CONSUMPTION_UNIT_PROXY) {
    throw new Error('CONSUMPTION_UNIT_PROXY environment variable is required');
  }

  // Load CR hashes from previous step
  console.log('📂 Loading CR hashes from previous step...');
  const crData = await loadCRHashes();
  console.log(`✅ Loaded ${crData.totalRecords} CRs for ${crData.totalUsers} users`);

  // One CU per user
  const expectedCUs = crData.totalUsers;

  console.log('\nConfiguration:');
  console.log(`  - Total Users: ${crData.totalUsers}`);
  console.log(`  - Total CRs: ${crData.totalRecords}`);
  console.log(`  - Expected CUs: ${expectedCUs} (one per user)`);
  console.log(`  - Batch Size: ${CONFIG.BATCH_SIZE}`);
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  const craWallet = new Wallet(CONFIG.PRIVATE_KEY, provider);

  console.log(`\n🔑 CRA Address: ${craWallet.address}`);
  console.log(`📝 Contract Address: ${CONFIG.CONSUMPTION_UNIT_PROXY}`);

  // Initialize client
  const cuClient = new ConsumptionUnitClient(
    CONFIG.CONSUMPTION_UNIT_PROXY,
    craWallet,
    provider
  );

  // Generate all CUs
  console.log('\n📋 Generating consumption units...');
  const startGenTime = Date.now();
  const allCUs = generateAllConsumptionUnits(crData);
  const genDuration = Date.now() - startGenTime;
  console.log(`✅ Generated ${allCUs.length} CUs in ${genDuration}ms`);

  // Save CU hashes for later use (TD creation)
  await saveCUHashesForUsers(allCUs);

  // Submit CUs
  const startSubmitTime = Date.now();
  const submissionResult = await submitCUsInBatches(cuClient, allCUs);
  const submitDuration = Date.now() - startSubmitTime;

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUBMISSION SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total CUs: ${allCUs.length}`);
  console.log(`Successful: ${submissionResult.successful} ✅`);
  console.log(`Failed: ${submissionResult.failed} ❌`);
  console.log(`Total Batches: ${submissionResult.totalBatches}`);
  console.log(`Total Duration: ${submitDuration}ms (${(submitDuration / 1000).toFixed(2)}s)`);
  console.log(`Average per CU: ${(submitDuration / allCUs.length).toFixed(2)}ms`);
  console.log(`Average per Batch: ${(submitDuration / submissionResult.totalBatches).toFixed(2)}ms`);

  // Calculate aggregation stats
  const totalCRsAggregated = allCUs.reduce((sum, cu) => sum + cu.consumptionRecordHashes.length, 0);
  console.log(`Total CRs Aggregated: ${totalCRsAggregated}`);
  console.log(`Average CRs per CU: ${(totalCRsAggregated / allCUs.length).toFixed(2)}`);
  console.log('='.repeat(60));

  // Show batch results
  if (submissionResult.results.length <= 20) {
    console.log('\n📋 Batch Results:');
    submissionResult.results.forEach(result => console.log(`  ${result}`));
  }


  return {
    totalUsers: crData.totalUsers,
    totalCUs: allCUs.length,
    successful: submissionResult.successful,
    failed: submissionResult.failed,
    consumptionUnits: allCUs
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

export { main, generateConsumptionUnit, generateAllConsumptionUnits };
