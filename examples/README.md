# Outbe L2 Examples

Example scripts for using Outbe L2 contracts.

## Quick Start

### 1. Start local network and deploy contracts

```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy contracts
make deploy-local
```

After deployment, update contract addresses in `examples/.env`.

### 2. Install dependencies

```bash
cd examples
npm install
```

### 3. Create test data

#### Generate Users

```bash
cd examples
npx ts-node scripts/generate-users.ts
```

**What it does:**
- Generates and founds test user accounts with private keys
- Saves user data to `scripts/generated-users.json`
- These users will be used for creating consumption records

#### Create Consumption Records (CR)

```bash
cd examples
npx ts-node scripts/create-consumption-records.ts
```

**What it does:**
- Automatically registers and activates CRA
- Uses generated user addresses from `scripts/generated-users.json`
- Generates consumption records for users
- Submits records in batches to the contract
- Saves CR hashes to `scripts/generated-cr-hashes.json`

**Configuration in `.env`:**
```env
TOTAL_USERS=10           # Number of users
RECORDS_PER_USER=5       # Records per user
BATCH_SIZE=10            # Batch size for submission
PROCESS_DELAY_MS=200     # Delay between batches
```

#### Create Consumption Units (CU)

```bash
npx ts-node scripts/create-consumption-units.ts
```

**What it does:**
- Loads CR hashes from `generated-cr-hashes.json`
- Groups CRs into Consumption Units
- Creates CUs in batches
- Saves CU IDs to `scripts/generated-cu-ids.json`


#### Create Tribute Drafts (TD)

```bash
npx ts-node scripts/create-tribute-drafts.ts
```

**What it does:**
- Loads CU IDs from `generated-cu-ids.json`
- Groups CUs into Tribute Drafts
- Creates TDs 
- Saves TD IDs to `scripts/generated-td-ids.json`

### 4. Full workflow (all commands)

```bash
cd examples

# 1. Generate users
npx ts-node scripts/generate-users.ts

# 2. Create CRs
npx ts-node scripts/create-consumption-records.ts

# 3. Create CUs from CRs
npx ts-node scripts/create-consumption-units.ts

# 4. Create TDs from CUs
npx ts-node scripts/create-tribute-drafts.ts
```


## Environment Variables (.env)

```env
# RPC
RPC_URL=http://localhost:8545

# Private key (Anvil default)
OWNER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Contract addresses (updated after deployment)
CRA_REGISTRY_PROXY=0x...
CONSUMPTION_RECORD_PROXY=0x...
CONSUMPTION_UNIT_PROXY=0x...
TRIBUTE_DRAFT_PROXY=0x...

# Test parameters
TOTAL_USERS=10
RECORDS_PER_USER=5
BATCH_SIZE=10
PROCESS_DELAY_MS=200

```
