/**
 * Create Active CRA Utility
 *
 * Helper functions for registering and activating CRAs
 */


import { CONFIG } from "./utils";
import { ethers, Wallet } from "ethers";
import { ICRARegistryAbi__factory } from "../contracts";

async function main() {
    console.log('Configuration:');
    console.log(`  - RPC URL: ${CONFIG.RPC_URL}`);
    console.log(`  - CRA Registry Address: ${CONFIG.CRA_REGISTRY_ADDRESS}`);
    console.log('🚀 Creating CRA to Registry');
    console.log('');

    // Setup provider and wallet
    const provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
    const ownerWallet = new Wallet(CONFIG.PRIVATE_KEY, provider);
    const craWallet = new Wallet(CONFIG.CRA_PRIVATE_KEY, provider);

    const registry = ICRARegistryAbi__factory.connect(CONFIG.CRA_REGISTRY_ADDRESS, ownerWallet);

    console.log(`CRA Address: ${craWallet.address}`);

    const isActive = await registry.isCRAActive(craWallet.address);

    if (isActive) {
        console.log(`✅ CRA is already registered and active`);
    } else {
        try {
            await registry.registerCRA(craWallet.address, "test-cra")
        } catch (error) {
            console.error('\n❌ registerCRA Error:', error);
            return
        }
        console.log(` ✅CRA Registered!`)
    }

    console.log("List all CRA:")

    let allCra = await registry.getAllCRAs()
    for (let cra of allCra) {
        console.log(" ->>  CRA", cra, "active", await registry.isCRAActive(cra))
    }
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
