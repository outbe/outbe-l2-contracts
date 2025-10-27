/**
 * Test Script: Create Consumption Records (CR) for thousands of users
 *
 * This script generates and submits consumption records for testing network scalability.
 * It creates thousands of CRs for multiple users using batch submission.
 *
 * Usage: ts-node create-consumption-records.ts
 */

import { BytesLike, ethers, Wallet } from 'ethers';
import { CONFIG, loadUsers } from "./utils";
import { ConsumptionRecordUpgradeableAbi__factory } from "../contracts";

type SubmitRequest = {
  crHash: string;
  owner: string;
  metadataKeys: string[];
  metadataValues: BytesLike[];
}

/**
 * Generate a batch of consumption records
 */
function generateSubmitRecords(
  users: Array<{ address: string; privateKey: string }>,
  recordsPerUser: number
): SubmitRequest[] {
  const records: SubmitRequest[] = [];

  const genTime = Date.now();
  for (let userIdx = 0; userIdx < users.length; userIdx++) {
    const ownerAddress = users[userIdx].address;

    for (let recIdx = 0; recIdx < recordsPerUser; recIdx++) {
      const crId = ethers.sha256(ethers.concat([
          ethers.toUtf8Bytes(ownerAddress),
          ethers.toUtf8Bytes(recIdx.toString()),
          ethers.toUtf8Bytes(genTime.toString()),
        ]
      ));

      records.push({
        crHash: crId,
        owner: ownerAddress,
        // TODO add metadata if needed
        metadataKeys: [],
        metadataValues: [],
      });
    }
  }

  return records;
}

/**
 * Save generated CR hashes to file for later use
 */
async function saveCRHashesForUsers(records: SubmitRequest[]): Promise<void> {
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


async function main() {
  console.log('🚀 Starting Consumption Record Generation Test\n');

  // Load users
  console.log('📂 Loading users...');
  const users = await loadUsers();
  console.log(`✅ Loaded ${users.length} users`);

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  const craWallet = new Wallet(CONFIG.CRA_PRIVATE_KEY, provider);

  console.log('\nConfiguration:');
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);
  console.log(`  - Total Users: ${users.length}`);
  console.log(`  - Records per User: ${CONFIG.RECORDS_PER_USER}`);
  console.log(`  - Total Records: ${users.length * CONFIG.RECORDS_PER_USER}`);
  console.log(`  - Batch Size: ${CONFIG.BATCH_SIZE}`);
  console.log(`  - 📝 Contract Address: ${CONFIG.CONSUMPTION_RECORD_ADDRESS}`);
  console.log(`  - 🔑 CRA Address: ${craWallet.address}`);

  // Initialize client
  let crClient = ConsumptionRecordUpgradeableAbi__factory
    .connect(CONFIG.CONSUMPTION_RECORD_ADDRESS, craWallet);

  crClient.totalSupply().then(supply => console.log(`Total CR Supply before: ${supply}`));

  // Generate all records
  console.log('\n📋 Generating consumption records...');

  const allRecords = generateSubmitRecords(users, CONFIG.RECORDS_PER_USER);

  // Encode each submit call
  const encodedCalls = allRecords.map(r =>
    crClient.interface.encodeFunctionData('submit', [r.crHash, r.owner, r.metadataKeys, r.metadataValues])
  );

  try {
    // Execute multicall with all encoded submit calls
    const tx = await crClient.multicall(encodedCalls);
    console.log(`⏳ Transaction submitted: ${tx.hash}`);

    // Wait for confirmation
    const receipt = await tx.wait();
    console.log(`✅ Batch confirmed in block ${receipt?.blockNumber}`);
    console.log(`   Gas used: ${receipt?.gasUsed.toString()}`);

  } catch (error: any) {
    console.error(`❌ Batch failed:`, error.message);
    throw error;
  }

  // Save CR hashes for later use (CU and TD creation)
  await saveCRHashesForUsers(allRecords);
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
