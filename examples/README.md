# Outbe L2 Examples

Example scripts in TypeScript for interaction with the Outbe L2 contracts.

## Quick Start

### 0. Prepare environment

Install dependencies:

```bash
npm install
```

Generate bindings for smart contracts:

```shell
npm run generate-types
```

Copy `.env.example` to `.env` to set environment variables required for running scripts and deployments.

```shell
cp .env.example .env
cp .env.example ../.env # copy to the repo root as well
```

Start Anvil (local node).

```shell
anvil
```

### 1. Deploy contracts

From the root directory, deploy contracts to the local node.

```shell
make deploy-local
```

### 2. Actual Examples Running Flow

#### Generate Users

```bash
npx ts-node scripts/generate-users.ts
```

**What it does:**

- Generates and founds test user accounts with private keys
- Saves user data to `scripts/results/generated-users.json`
- These users will be used for creating consumption records

#### Create Consumption Records (CR)

```bash
npx ts-node scripts/create-consumption-records.ts
```

**What it does:**

- Automatically registers and activates CRA
- Uses generated user addresses from `scripts/results/generated-users.json`
- Generates consumption records for users
- Submits records in batches to the contract
- Saves CR hashes to `scripts/results/generated-cr-hashes.json`

**See configuration in `.env`:**

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
- Saves CU IDs to `scripts/results/generated-cu-ids.json`

#### Create Tribute Drafts (TD)

```bash
npx ts-node scripts/create-tribute-drafts.ts
```

**What it does:**

- Loads CU IDs from `generated-cu-ids.json`
- Groups CUs into Tribute Drafts
- Creates TDs 
