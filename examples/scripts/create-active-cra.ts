/**
 * Create Active CRA Utility
 *
 * Helper functions for registering and activating CRAs
 */

import { CRARegistryClient, CRAStatus } from '../lib/cra-registry';

/**
 * Create and activate CRA (register if needed, then set status to Active)
 */
export async function createActiveCRA(
  registryClient: CRARegistryClient,
  craAddress: string,
  name: string = 'Test CRA'
): Promise<void> {
  console.log('\n🔍 Checking CRA registration status...');

  try {
    const isActive = await registryClient.isCraActive(craAddress);

    if (isActive) {
      console.log(`✅ CRA ${craAddress} is already registered and active`);
      return;
    }

    console.log(`⚠️  CRA ${craAddress} is not active`);

    // Try to register
    try {
      await registryClient.registerCra(craAddress, name);
      console.log(`✅ CRA registered successfully`);
    } catch (regError: any) {
      if (!regError.message.includes('already registered')) {
        throw regError;
      }
      console.log(`ℹ️  CRA is already registered`);
    }

    // Ensure status is Active
    console.log(`🔄 Setting CRA status to Active...`);
    await registryClient.updateCraStatus(craAddress, CRAStatus.Active);
    console.log(`✅ CRA status set to Active`);

  } catch (error: any) {
    console.error(`❌ Failed to setup CRA:`, error.message);
    throw error;
  }
}
