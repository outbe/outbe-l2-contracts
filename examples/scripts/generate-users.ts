/**
 * Test Script: Generate Test Users
 *
 * This script generates deterministic test users with private keys
 * and funds them with ETH for gas fees.
 *
 * Usage: ts-node generate-users.ts
 */

import { ethers, Wallet } from 'ethers';
import { CONFIG } from "./utils";

/**
 * Generate random users
 */
function generateUsers(count: number): Array<{ address: string; privateKey: string }> {
  const users: Array<{ address: string; privateKey: string }> = [];

  for (let i = 0; i < count; i++) {
    const wallet = ethers.Wallet.createRandom();
    users.push({
      address: wallet.address,
      privateKey: wallet.privateKey
    });
  }

  return users;
}

/**
 * Fund users with ETH for gas
 */
async function fundUsers(
  users: Array<{ address: string; privateKey: string }>,
  funder: Wallet,
  amountEth: string
): Promise<{ successful: number; failed: number }> {
  let successful = 0;
  let failed = 0;

  console.log(`\n💰 Funding ${users.length} users with ${amountEth} ETH each...`);

  const amount = ethers.parseEther(amountEth);

  for (let i = 0; i < users.length; i++) {
    const user = users[i];
    try {
      console.log(`  ⏳ Funding user ${i + 1}/${users.length} (${user.address.slice(0, 10)}...)...`);

      const tx = await funder.sendTransaction({
        to: user.address,
        value: amount
      });

      await tx.wait();
      successful++;
      console.log(`  ✅ User ${i + 1} funded`);
      await new Promise(resolve => setTimeout(resolve, CONFIG.PROCESS_DELAY_MS));

    } catch (error: any) {
      failed++;
      console.error(`  ❌ User ${i + 1} funding failed:`, error.message);
    }
  }

  return {successful, failed};
}

/**
 * Save generated users to file
 */
async function saveUsers(users: Array<{ address: string; privateKey: string }>): Promise<void> {
  const fs = await import('fs');
  const path = await import('path');

  const outputData = {
    generatedAt: new Date().toISOString(),
    totalUsers: users.length,
    users: users.map((user, index) => ({
      index,
      address: user.address,
      privateKey: user.privateKey
    }))
  };

  const resultsDir = path.join(__dirname, 'results');
  if (!fs.existsSync(resultsDir)) {
    fs.mkdirSync(resultsDir, {recursive: true});
  }

  const outputPath = path.join(resultsDir, 'generated-users.json');
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2));

  console.log(`\n💾 Saved users to: ${outputPath}`);
}

/**
 * Main execution function
 */
async function main() {
  console.log('🚀 Starting User Generation and Funding\n');

  console.log('Configuration:');
  console.log(`  - Total Users: ${CONFIG.TOTAL_USERS}`);
  console.log(`  - Funding Amount: ${CONFIG.FUNDING_AMOUNT} ETH per user`);
  console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);

  // Generate users
  console.log('\n📋 Generating users...');
  const users = generateUsers(CONFIG.TOTAL_USERS);
  console.log(`✅ Generated ${users.length} users`);

  // Setup funder wallet
  const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
  const funder = new Wallet(CONFIG.PRIVATE_KEY, provider);

  console.log(`\n🔑 Funder Address: ${funder.address}`);

  // Check funder balance
  const balance = await provider.getBalance(funder.address);
  const requiredBalance = ethers.parseEther(CONFIG.FUNDING_AMOUNT) * BigInt(users.length);
  console.log(`💰 Funder Balance: ${ethers.formatEther(balance)} ETH`);
  console.log(`💰 Required Balance: ${ethers.formatEther(requiredBalance)} ETH`);

  if (balance < requiredBalance) {
    throw new Error('Insufficient balance in funder account');
  }

  // Fund users
  const startTime = Date.now();
  const fundingResult = await fundUsers(users, funder, CONFIG.FUNDING_AMOUNT);
  const duration = Date.now() - startTime;

  // Save users
  await saveUsers(users);

  // Print summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total Users Generated: ${users.length}`);
  console.log(`Successfully Funded: ${fundingResult.successful} ✅`);
  console.log(`Failed to Fund: ${fundingResult.failed} ❌`);
  console.log(`Total Duration: ${duration}ms (${(duration / 1000).toFixed(2)}s)`);
  console.log(`Total ETH Sent: ${ethers.formatEther(ethers.parseEther(CONFIG.FUNDING_AMOUNT) * BigInt(fundingResult.successful))} ETH`);
  console.log('='.repeat(60));

  console.log('\n✨ User generation completed!');

  return users;
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
