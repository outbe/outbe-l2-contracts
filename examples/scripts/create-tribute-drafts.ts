/**
 * Test Script: Create Tribute Drafts (TD) from Consumption Units
 *
 * This script generates and submits tribute drafts for testing network scalability.
 * It aggregates previously created CUs into TDs for thousands of users.
 *
 * Usage: ts-node create-tribute-drafts.ts
 */

import { ethers, Wallet } from 'ethers';
import { config } from 'dotenv';
import { resolve } from 'path';
import {
  TributeDraftClient,
  TributeDraftBuilder,
  TributeDraftAggregator,
  MintTributeDraftParams
} from '../lib/tribute-draft';

// Load environment variables from examples/.env
config({ path: resolve(__dirname, '../.env') });

// Configuration
const CONFIG = {
  // Network settings
  RPC_URL: process.env.RPC_URL!,
  PRIVATE_KEY: process.env.OWNER_PRIVATE_KEY!,
  TRIBUTE_DRAFT_PROXY: process.env.TRIBUTE_DRAFT_PROXY!,

  // Test parameters
  PROCESS_DELAY_MS: parseInt(process.env.PROCESS_DELAY_MS!), // Delay between submissions

  // Input files from previous steps
  CU_HASHES_FILE: './results/generated-cu-hashes.json',
  USERS_FILE: './results/generated-users.json',
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
 * Load CU hashes from the previous script
 */
async function loadCUHashes(): Promise<{
  totalUsers: number;
  totalCUs: number;
  users: Array<{
    owner: string;
    totalCUs: number;
    consumptionUnits: Array<{
      cuHash: string;
      worldwideDay: string;
      settlementCurrency: string;
      crCount: number;
    }>;
  }>;
}> {
  const fs = await import('fs');
  const path = await import('path');

  const filePath = path.resolve(__dirname, CONFIG.CU_HASHES_FILE);

  if (!fs.existsSync(filePath)) {
    throw new Error(`CU hashes file not found: ${filePath}\nPlease run create-consumption-units.ts first.`);
  }

  const data = fs.readFileSync(filePath, 'utf-8');
  return JSON.parse(data);
}

/**
 * Group CUs by owner, day, and currency (required for TD aggregation)
 */
function groupCUsForAggregation(
  cus: Array<{
    cuHash: string;
    worldwideDay: string;
    settlementCurrency: string;
    crCount: number;
  }>
): Map<string, string[]> {
  const groups = new Map<string, string[]>();

  for (const cu of cus) {
    // Create a key that combines day and currency
    const key = `${cu.worldwideDay}_${cu.settlementCurrency}`;

    if (!groups.has(key)) {
      groups.set(key, []);
    }

    groups.get(key)!.push(cu.cuHash);
  }

  return groups;
}

/**
 * Generate tribute draft mint parameters for a user
 */
function generateTributeDraftsForUser(
  owner: string,
  cus: Array<{
    cuHash: string;
    worldwideDay: string;
    settlementCurrency: string;
    crCount: number;
  }>
): Array<{ params: MintTributeDraftParams; metadata: { day: string; currency: string; cuCount: number } }> {
  const tributeDrafts: Array<{
    params: MintTributeDraftParams;
    metadata: { day: string; currency: string; cuCount: number };
  }> = [];

  // Group CUs by day and currency
  const groups = groupCUsForAggregation(cus);

  for (const [key, cuHashes] of groups.entries()) {
    const [day, currency] = key.split('_');

    // Create one TD per group (day + currency)
    if (cuHashes.length === 0) continue;

    const params = new TributeDraftBuilder()
      .setConsumptionUnits(cuHashes)
      .build();

    tributeDrafts.push({
      params,
      metadata: {
        day,
        currency,
        cuCount: cuHashes.length
      }
    });
  }

  return tributeDrafts;
}

/**
 * Submit tribute drafts for a single user
 */
async function submitTributeDraftsForUser(
  provider: ethers.JsonRpcProvider,
  contractAddress: string,
  userPrivateKey: string,
  owner: string,
  userIndex: number,
  tributeDrafts: Array<{
    params: MintTributeDraftParams;
    metadata: { day: string; currency: string; cuCount: number };
  }>
): Promise<{
  userIndex: number;
  owner: string;
  successful: number;
  failed: number;
  results: Array<{ tdId: string; txHash: string; metadata: any }>;
}> {
  // Create client with user's wallet
  const userWallet = new Wallet(userPrivateKey, provider);
  const client = new TributeDraftClient(contractAddress, userWallet, provider);
  const results: Array<{ tdId: string; txHash: string; metadata: any }> = [];
  let successful = 0;
  let failed = 0;

  console.log(`\n👤 Processing User ${userIndex + 1} (${owner.slice(0, 10)}...)`);
  console.log(`   - Tribute Drafts to mint: ${tributeDrafts.length}`);

  for (let i = 0; i < tributeDrafts.length; i++) {
    const td = tributeDrafts[i];

    try {
      console.log(`   ⏳ Minting TD ${i + 1}/${tributeDrafts.length} (${td.metadata.cuCount} CUs)...`);

      const startTime = Date.now();
      const result = await client.mint(td.params);
      const duration = Date.now() - startTime;

      results.push({
        tdId: result.tributeDraftId,
        txHash: result.transactionHash,
        metadata: td.metadata
      });

      successful++;
      console.log(`   ✅ TD ${i + 1} minted in ${duration}ms (ID: ${result.tributeDraftId.slice(0, 10)}...)`);

      // Delay between submissions to avoid overwhelming the network
      if (i < tributeDrafts.length - 1) {
        await new Promise(resolve => setTimeout(resolve, CONFIG.PROCESS_DELAY_MS));
      }

    } catch (error: any) {
      failed++;
      const errorMsg = error.message || String(error);
      console.error(`   ❌ TD ${i + 1} failed: ${errorMsg.slice(0, 100)}`);

      // Continue with next TD
      continue;
    }
  }

  return {
    userIndex,
    owner,
    successful,
    failed,
    results
  };
}

/**
 * Submit all tribute drafts for all users
 */
async function submitAllTributeDrafts(
  provider: ethers.JsonRpcProvider,
  contractAddress: string,
  users: Array<{ address: string; privateKey: string }>,
  cuData: {
    totalUsers: number;
    totalCUs: number;
    users: Array<{
      owner: string;
      totalCUs: number;
      consumptionUnits: Array<{
        cuHash: string;
        worldwideDay: string;
        settlementCurrency: string;
        crCount: number;
      }>;
    }>;
  }
): Promise<{
  totalUsers: number;
  totalTDs: number;
  successful: number;
  failed: number;
  userResults: Array<{
    userIndex: number;
    owner: string;
    successful: number;
    failed: number;
    results: Array<{ tdId: string; txHash: string; metadata: any }>;
  }>;
}> {
  const userResults = [];
  let totalTDs = 0;
  let totalSuccessful = 0;
  let totalFailed = 0;

  console.log(`\n📦 Processing ${cuData.totalUsers} users...`);

  for (let userIndex = 0; userIndex < cuData.users.length; userIndex++) {
    const user = cuData.users[userIndex];

    // Find corresponding user with private key
    const userWithKey = users.find(u => u.address.toLowerCase() === user.owner.toLowerCase());
    if (!userWithKey) {
      console.log(`\n👤 User ${userIndex + 1} - No private key found (skipping)`);
      continue;
    }

    // Generate TDs for this user
    const tributeDrafts = generateTributeDraftsForUser(user.owner, user.consumptionUnits);
    totalTDs += tributeDrafts.length;

    if (tributeDrafts.length === 0) {
      console.log(`\n👤 User ${userIndex + 1} - No TDs to mint (skipping)`);
      continue;
    }

    // Submit TDs for this user
    const userResult = await submitTributeDraftsForUser(
      provider,
      contractAddress,
      userWithKey.privateKey,
      user.owner,
      userIndex,
      tributeDrafts
    );

    totalSuccessful += userResult.successful;
    totalFailed += userResult.failed;
    userResults.push(userResult);

    // Progress update
    if ((userIndex + 1) % 10 === 0) {
      console.log(`\n📊 Progress: ${userIndex + 1}/${cuData.totalUsers} users processed`);
    }
  }

  return {
    totalUsers: cuData.totalUsers,
    totalTDs,
    successful: totalSuccessful,
    failed: totalFailed,
    userResults
  };
}

/**
 * Save generated TD IDs to file
 */
async function saveTDResults(
  results: {
    totalUsers: number;
    totalTDs: number;
    successful: number;
    failed: number;
    userResults: Array<{
      userIndex: number;
      owner: string;
      successful: number;
      failed: number;
      results: Array<{ tdId: string; txHash: string; metadata: any }>;
    }>;
  }
): Promise<void> {
  const fs = await import('fs');
  const path = await import('path');

  const outputData = {
    generatedAt: new Date().toISOString(),
    totalUsers: results.totalUsers,
    totalTDs: results.totalTDs,
    successful: results.successful,
    failed: results.failed,
    users: results.userResults.map(user => ({
      owner: user.owner,
      totalTDs: user.successful + user.failed,
      successful: user.successful,
      failed: user.failed,
      tributeDrafts: user.results
    }))
  };

  const outputPath = path.join(__dirname, 'results/generated-td-results.json');
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));

  console.log(`\n💾 Saved TD results to: ${outputPath}`);
}

/**
 * Main execution function
 */
async function main() {
  console.log('🚀 Starting Tribute Draft Generation Test\n');

  if (!CONFIG.TRIBUTE_DRAFT_PROXY) {
    throw new Error('TRIBUTE_DRAFT_PROXY environment variable is required');
  }

  // Load users
  console.log('📂 Loading users...');
  const users = await loadUsers();
  console.log(`✅ Loaded ${users.length} users`);

  // Load CU hashes from previous step
  console.log('📂 Loading CU hashes from previous step...');
  const cuData = await loadCUHashes();
  console.log(`✅ Loaded ${cuData.totalCUs} CUs for ${cuData.totalUsers} users`);

  let estimatedTDs = 0;
  for (const user of cuData.users) {
    const groups = groupCUsForAggregation(user.consumptionUnits);
    estimatedTDs += groups.size;
  }

  console.log('\nConfiguration:');
  console.log(`  - Total Users: ${cuData.totalUsers}`);
  console.log(`  - Total CUs: ${cuData.totalCUs}`);
  console.log(`  - Estimated TDs: ~${estimatedTDs} (one per day/currency group)`);
  console.log(`  - Process Delay: ${CONFIG.PROCESS_DELAY_MS}ms`);
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);

  // Setup provider
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);

  console.log(`\n📝 Contract Address: ${CONFIG.TRIBUTE_DRAFT_PROXY}`);

  // Submit all TDs
  console.log('\n📋 Starting Tribute Draft submission...');
  const startTime = Date.now();
  const submissionResult = await submitAllTributeDrafts(
    provider,
    CONFIG.TRIBUTE_DRAFT_PROXY,
    users,
    cuData
  );
  const duration = Date.now() - startTime;

  // Save results
  await saveTDResults(submissionResult);

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUBMISSION SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total Users Processed: ${submissionResult.totalUsers}`);
  console.log(`Total TDs: ${submissionResult.totalTDs}`);
  console.log(`Successful: ${submissionResult.successful} ✅`);
  console.log(`Failed: ${submissionResult.failed} ❌`);
  console.log(`Success Rate: ${((submissionResult.successful / submissionResult.totalTDs) * 100).toFixed(1)}%`);
  console.log(`Total Duration: ${duration}ms (${(duration / 1000).toFixed(2)}s)`);
  console.log(`Average per TD: ${(duration / submissionResult.totalTDs).toFixed(2)}ms`);

  // Calculate aggregation stats
  const totalCUsAggregated = submissionResult.userResults.reduce(
    (sum, user) => sum + user.results.reduce((s, td) => s + td.metadata.cuCount, 0),
    0
  );
  console.log(`Total CUs Aggregated: ${totalCUsAggregated}`);
  console.log(`Average CUs per TD: ${(totalCUsAggregated / submissionResult.successful).toFixed(2)}`);
  console.log('='.repeat(60));

  // Show per-user summary
  console.log('\n📋 Per-User Summary (first 10):');
  const displayCount = Math.min(10, submissionResult.userResults.length);
  for (let i = 0; i < displayCount; i++) {
    const user = submissionResult.userResults[i];
    console.log(
      `  ${i + 1}. ${user.owner.slice(0, 10)}... - ` +
      `${user.successful}/${user.successful + user.failed} TDs minted ` +
      `(${user.results.length} total)`
    );
  }

  if (submissionResult.userResults.length > 10) {
    console.log(`  ... and ${submissionResult.userResults.length - 10} more users`);
  }

  // Test: Verify some random TDs
  console.log('\n🔍 Verifying random sample...');
  const allTDs = submissionResult.userResults.flatMap(u => u.results);
  const sampleSize = Math.min(5, allTDs.length);

  // Create a client for verification (can use any wallet for view functions)
  const verifyWallet = new Wallet(CONFIG.PRIVATE_KEY, provider);
  const tdClient = new TributeDraftClient(CONFIG.TRIBUTE_DRAFT_PROXY, verifyWallet, provider);

  for (let i = 0; i < sampleSize; i++) {
    const randomIdx = Math.floor(Math.random() * allTDs.length);
    const td = allTDs[randomIdx];

    try {
      const record = await tdClient.get(td.tdId);
      if (record) {
        const amount = TributeDraftClient.formatAmount(
          record.settlementBaseAmount,
          record.settlementAttoAmount
        );
        console.log(
          `  ${i + 1}. ${td.tdId.slice(0, 10)}... - ✅ ${amount} ${record.settlementCurrency}, ` +
          `${record.cuHashes.length} CUs, ${record.worldwideDay}`
        );
      } else {
        console.log(`  ${i + 1}. ${td.tdId.slice(0, 10)}... - ❌ Not found`);
      }
    } catch (error) {
      console.log(`  ${i + 1}. ${td.tdId.slice(0, 10)}... - ❌ Error checking`);
    }
  }

  console.log('\n✨ Test completed!');

  return submissionResult;
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

export { main, loadUsers, generateTributeDraftsForUser, groupCUsForAggregation };
