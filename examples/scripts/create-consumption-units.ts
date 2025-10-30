/**
 * Test Script: Create Consumption Units (CU) from Consumption Records
 *
 * This script generates and submits consumption units for testing network scalability.
 * It aggregates previously created CRs into CUs for thousands of users.
 *
 * Usage: ts-node create-consumption-units.ts
 */

import { type BigNumberish, ethers, Wallet } from 'ethers';
import { CONFIG } from "./utils";
import { ConsumptionUnitUpgradeableAbi__factory, IConsumptionUnitAbi__factory } from "../contracts";

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

type SubmitRequest = {
  id: string;
  owner: string;
  worldwideDay: number;
  settlementAmountBase: BigNumberish;
  settlementAmountAtto: BigNumberish;
  settlementCurrency: number;
  crHashes: string[];
  amendmentCrHashes: string[];
};

/**
 * Generate all CUs from CR hashes
 */
function generateAllConsumptionUnits(
  crData: { totalUsers: number; totalRecords: number; users: Array<{ owner: string; crHashes: string[] }> }
): SubmitRequest[] {
  const consumptionUnits: SubmitRequest[] = [];

  for (let userIndex = 0; userIndex < crData.users.length; userIndex++) {
    const user = crData.users[userIndex];

    // Create one CU aggregating all CRs for this user
    if (user.crHashes.length > 0) {
      const cu = generateConsumptionUnit(user.owner, user.crHashes,);
      consumptionUnits.push(cu);
    }
  }

  return consumptionUnits;
}

/**
 * Generate a CU from a group of CR hashes
 */
function generateConsumptionUnit(owner: string, crHashes: string[],): SubmitRequest {
  // Generate deterministic worldwide day in YYYYMMDD format
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const worldwideDay = parseInt(`${year}${month}${day}`); // e.g., 20240115

  // Calculate amounts based on number of CRs
  const baseAmount = BigInt(Math.floor(crHashes.length * 100 + Math.random() * 50)); // $100-150 per CR
  const attoAmount = BigInt(Math.floor(Math.random() * 1e17)); // Random fractional part

  // generate ID
  const crHashesBytes = ethers.concat(crHashes.map(it => ethers.toUtf8Bytes(it)))
  const id = ethers.sha256(ethers.concat([
      ethers.toUtf8Bytes(owner),
      ethers.toUtf8Bytes(crHashesBytes),
    ]
  ));

  // Build CU parameters
  return {
    id: id,
    owner: owner,
    settlementAmountBase: baseAmount,
    settlementAmountAtto: attoAmount,
    settlementCurrency: 840,
    worldwideDay: worldwideDay,
    crHashes: crHashes,
    amendmentCrHashes: [],
  }
}

/**
 * Save generated CU hashes to file for later use (Tribute Drafts)
 */
async function saveCUHashesForUsers(consumptionUnits: SubmitRequest[]): Promise<void> {
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
      cuHash: cu.id,
      worldwideDay: cu.worldwideDay,
      settlementCurrency: cu.settlementCurrency,
      crCount: cu.crHashes.length
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

  // Load CR hashes from previous step
  console.log('📂 Loading CR hashes from previous step...');
  const crData = await loadCRHashes();
  console.log(`✅ Loaded ${crData.totalRecords} CRs for ${crData.totalUsers} users`);

  // One CU per user
  const expectedCUs = crData.totalUsers;

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  const craWallet = new Wallet(CONFIG.PRIVATE_KEY, provider);


  console.log('\nConfiguration:');
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);
  console.log(`  - Total Users: ${crData.totalUsers}`);
  console.log(`  - Total CRs: ${crData.totalRecords}`);
  console.log(`  - Expected CUs: ${expectedCUs} (one per user)`);
  console.log(`  - Batch Size: ${CONFIG.BATCH_SIZE}`);
  console.log(`  - 🔑 CRA Address: ${craWallet.address}`);
  console.log(`  - 📝 Contract Address: ${CONFIG.CONSUMPTION_UNIT_ADDRESS}`);

  // Initialize client
  const cuClient = IConsumptionUnitAbi__factory.connect(CONFIG.CONSUMPTION_UNIT_ADDRESS, craWallet);

  // Generate all CUs
  console.log('\n📋 Generating consumption units...');
  const allCUs = generateAllConsumptionUnits(crData);

  console.log(`✅ Generated ${allCUs.length} CUs`);

  // Encode each submit call
  const encodedCalls = allCUs.map(r =>
    cuClient.interface.encodeFunctionData('submit', [
      r.id,
      r.owner,
      r.settlementCurrency,
      r.worldwideDay,
      r.settlementAmountBase,
      r.settlementAmountAtto,
      r.crHashes,
      r.amendmentCrHashes
    ]));

  try {
    // Execute multicall with all encoded submit calls
    const tx = await cuClient.multicall(encodedCalls);
    console.log(`⏳ Transaction submitted: ${tx.hash}`);

    // Wait for confirmation
    const receipt = await tx.wait();
    console.log(`✅ Batch confirmed in block ${receipt?.blockNumber}`);
    console.log(`   Gas used: ${receipt?.gasUsed.toString()}`);

  } catch (error: any) {
    console.error(`❌ Batch failed:`, error.message);
    throw error;
  }

  // Save CU hashes for later use (TD creation)
  await saveCUHashesForUsers(allCUs);
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
