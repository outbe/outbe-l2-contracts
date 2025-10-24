import {config} from 'dotenv';
import {resolve} from 'path';

// Load environment variables from examples/.env
config({path: resolve(__dirname, '../.env')});

// Configuration
export const CONFIG = {
    RPC_URL: process.env.RPC_URL!,
    PRIVATE_KEY: process.env.PRIVATE_KEY!,
    CRA_PRIVATE_KEY: process.env.CRA_PRIVATE_KEY!,

    // Contracts
    CRA_REGISTRY_ADDRESS: process.env.CRA_REGISTRY_ADDRESS!,
    CONSUMPTION_RECORD_ADDRESS: process.env.CONSUMPTION_RECORD_ADDRESS!,
    TRIBUTE_DRAFT_ADDRESS: process.env.TRIBUTE_DRAFT_ADDRESS!,

    // Test parameters
    RECORDS_PER_USER: parseInt(process.env.RECORDS_PER_USER!),
    BATCH_SIZE: parseInt(process.env.BATCH_SIZE!), // Max is typically 100
    TOTAL_USERS: parseInt(process.env.TOTAL_USERS!),
    FUNDING_AMOUNT: process.env.FUNDING_AMOUNT || '1', // ETH per user
    PROCESS_DELAY_MS: parseInt(process.env.PROCESS_DELAY_MS!),

    // Input file
    USERS_FILE: './results/generated-users.json',

    // Energy sources for realistic data
    ENERGY_SOURCES: ['solar', 'wind', 'hydro', 'geothermal', 'biomass'],
    ENERGY_UNITS: ['kWh', 'MWh', 'GWh'],
};

/**
 * Load users from the generated users file
 */
export async function loadUsers(): Promise<Array<{ address: string; privateKey: string }>> {
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

