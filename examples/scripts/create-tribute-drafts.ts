/**
 * Test Script: Create Tribute Drafts (TD) from Consumption Units
 *
 * This script generates and submits tribute drafts for testing network scalability.
 * It aggregates previously created CUs into TDs for thousands of users.
 *
 * Usage: ts-node create-tribute-drafts.ts
 */

import { ethers, Wallet } from 'ethers';
import { CONFIG, loadUsers } from "./utils";
import { TributeDraftUpgradeableAbi__factory } from "../contracts";

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
      worldwideDay: number;
      settlementCurrency: number;
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
 * Main execution function
 */
async function main() {
  console.log('🚀 Starting Tribute Draft Generation Test\n');
  // Load users
  console.log('📂 Loading users...');
  const users = await loadUsers();
  console.log(`✅ Loaded ${users.length} users`);

  // Load CU hashes from previous step
  console.log('📂 Loading CU hashes from previous step...');
  const cuData = await loadCUHashes();
  console.log(`✅ Loaded ${cuData.totalCUs} CUs for ${cuData.totalUsers} users`);

  console.log('\nConfiguration:');
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);
  console.log(`  - Total Users: ${cuData.totalUsers}`);
  console.log(`  - Total CUs: ${cuData.totalCUs}`);
  console.log(`  - 📝 Contract Address: ${CONFIG.TRIBUTE_DRAFT_ADDRESS}`);

  // Setup provider
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);

  // Submit all TDs
  console.log('\n📋 Starting Tribute Draft submission...');
  for (let user of cuData.users) {
    const pk = users.find(u => u.address.toLowerCase() === user.owner.toLowerCase())?.privateKey!;
    let tributeDraftClient = TributeDraftUpgradeableAbi__factory.connect(CONFIG.TRIBUTE_DRAFT_ADDRESS, new Wallet(pk, provider))
    await tributeDraftClient.submit(user.consumptionUnits.map(cu => cu.cuHash))
  }

  console.log('Submission completed!');
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
