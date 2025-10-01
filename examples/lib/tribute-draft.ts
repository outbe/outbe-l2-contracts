/**
 * Outbe L2 - TributeDraftUpgradeable TypeScript Integration Example
 * 
 * This example demonstrates how to interact with the TributeDraftUpgradeable contract
 * using ethers.js. TributeDrafts are user-mintable tokens that aggregate multiple
 * ConsumptionUnits into a single tradeable asset.
 * 
 * Features:
 * - Mint tribute drafts from consumption units (any user as owner)
 * - Query tribute draft details
 * - Automatic aggregation validation and amount summation
 * - Event monitoring for minting
 * - UUPS upgrade functionality
 * 
 * @author Outbe Team
 * @version 1.0.0
 */

import { ethers, Contract, Wallet, Provider } from 'ethers';

// TributeDraftUpgradeable ABI (key functions only)
const TRIBUTE_DRAFT_ABI = [
  // Core functions
  'function submit(bytes32[] cuHashes) external returns (bytes32 tdId)',
  'function getTributeDraft(bytes32 tdId) external view returns (tuple(bytes32 tributeDraftId, address owner, uint16 settlementCurrency, uint32 worldwideDay, uint256 settlementAmountBase, uint256 settlementAmountAtto, bytes32[] cuHashes, uint256 submittedAt))',
  'function getConsumptionUnitAddress() external view returns (address)',
  'function setConsumptionUnitAddress(address consumptionUnitAddress) external',
  
  // Upgrade functions (owner only)
  'function upgradeTo(address newImplementation) external',
  'function upgradeToAndCall(address newImplementation, bytes data) external payable',
  
  // Ownable functions
  'function owner() external view returns (address)',
  'function transferOwnership(address newOwner) external',
  
  // Events
  'event Submited(bytes32 indexed tdId, address indexed owner, address indexed submittedBy, uint256 cuCount, uint256 timestamp)',
  'event Upgraded(address indexed implementation)',

  // Errors
  'error EmptyArray()',
  'error AlreadyExists()',
  'error NotFound(bytes32 cuHash)',
  'error NotSameOwner()',
  'error NotSettlementCurrencyCurrency()',
  'error NotSameWorldwideDay()'
];

/**
 * TributeDraft data structure
 */
export interface TributeDraftEntity {
  tributeDraftId: string;
  owner: string;
  settlementCurrency: number;
  worldwideDay: number;
  settlementAmountBase: bigint;
  settlementAmountAtto: bigint;
  cuHashes: string[];
  submittedAt: bigint;
}

/**
 * Parameters for minting tribute drafts
 */
export interface MintTributeDraftParams {
  consumptionUnitHashes: string[];
}

/**
 * Builder for constructing tribute draft mint parameters
 */
export class TributeDraftBuilder {
  private cuHashes: string[] = [];

  /**
   * Add a consumption unit hash to the tribute draft
   */
  addConsumptionUnit(cuHash: string): TributeDraftBuilder {
    if (this.cuHashes.includes(cuHash)) {
      throw new Error(`Consumption unit hash already added: ${cuHash}`);
    }
    this.cuHashes.push(cuHash);
    return this;
  }

  /**
   * Add multiple consumption unit hashes
   */
  addConsumptionUnits(cuHashes: string[]): TributeDraftBuilder {
    for (const cuHash of cuHashes) {
      this.addConsumptionUnit(cuHash);
    }
    return this;
  }

  /**
   * Set all consumption unit hashes (replaces existing)
   */
  setConsumptionUnits(cuHashes: string[]): TributeDraftBuilder {
    // Check for duplicates
    const unique = new Set(cuHashes);
    if (unique.size !== cuHashes.length) {
      throw new Error('Duplicate consumption unit hashes provided');
    }
    this.cuHashes = [...cuHashes];
    return this;
  }

  /**
   * Clear all consumption unit hashes
   */
  clear(): TributeDraftBuilder {
    this.cuHashes = [];
    return this;
  }

  /**
   * Get the current consumption unit hashes
   */
  getConsumptionUnits(): string[] {
    return [...this.cuHashes];
  }

  /**
   * Build the mint parameters
   */
  build(): MintTributeDraftParams {
    if (this.cuHashes.length === 0) {
      throw new Error('At least one consumption unit hash must be provided');
    }

    return {
      consumptionUnitHashes: [...this.cuHashes]
    };
  }
}

/**
 * TributeDraft contract client with full functionality
 */
export class TributeDraftClient {
  private contract: Contract;
  private signer: Wallet;
  private provider: Provider;

  constructor(contractAddress: string, signer: Wallet, provider: Provider) {
    this.contract = new Contract(contractAddress, TRIBUTE_DRAFT_ABI, signer);
    this.signer = signer;
    this.provider = provider;
  }

  /**
   * Submit a tribute draft from consumption units
   * All consumption units must:
   * - Be owned by the caller
   * - Have the same settlement currency
   * - Have the same worldwide day
   * - Not have been used in other tribute drafts
   */
  async mint(params: MintTributeDraftParams): Promise<{ tributeDraftId: string; transactionHash: string }> {
    if (params.consumptionUnitHashes.length === 0) {
      throw new Error('At least one consumption unit hash must be provided');
    }

    try {
      const tx = await this.contract.submit(params.consumptionUnitHashes);
      const receipt = await tx.wait();

      // Extract the TributeDraft ID from the Submited event
      const submitedEvent = receipt.logs?.find((log: any) => {
        try {
          const parsed = this.contract.interface.parseLog(log);
          return parsed && parsed.name === 'Submited';
        } catch {
          return false;
        }
      });

      let tributeDraftId = '';
      if (submitedEvent) {
        const parsed = this.contract.interface.parseLog(submitedEvent);
        tributeDraftId = parsed?.args.tdId || '';
      }

      console.log(`Tribute draft submitted: ${tributeDraftId} (${params.consumptionUnitHashes.length} CUs)`);
      return {
        tributeDraftId,
        transactionHash: receipt.transactionHash
      };
    } catch (error: any) {
      this.handleError(error, 'submit');
      throw error;
    }
  }

  /**
   * Get tribute draft details
   */
  async get(tributeDraftId: string): Promise<TributeDraftEntity | null> {
    try {
      const result = await this.contract.getTributeDraft(tributeDraftId);

      // Check if tribute draft exists (owner will be zero address if not found)
      if (result.owner === ethers.ZeroAddress) {
        return null;
      }

      return {
        tributeDraftId: result.tributeDraftId,
        owner: result.owner,
        settlementCurrency: result.settlementCurrency,
        worldwideDay: result.worldwideDay,
        settlementAmountBase: result.settlementAmountBase,
        settlementAmountAtto: result.settlementAmountAtto,
        cuHashes: result.cuHashes,
        submittedAt: result.submittedAt
      };
    } catch (error: any) {
      this.handleError(error, 'get');
      throw error;
    }
  }

  /**
   * Get the ConsumptionUnit contract address
   */
  async getConsumptionUnitAddress(): Promise<string> {
    return await this.contract.getConsumptionUnitAddress();
  }

  /**
   * Set the ConsumptionUnit contract address (owner only)
   */
  async setConsumptionUnitAddress(consumptionUnitAddress: string): Promise<string> {
    try {
      const tx = await this.contract.setConsumptionUnitAddress(consumptionUnitAddress);
      const receipt = await tx.wait();
      console.log(`Consumption Unit address updated: ${consumptionUnitAddress}`);
      return receipt.transactionHash;
    } catch (error: any) {
      this.handleError(error, 'setConsumptionUnitAddress');
      throw error;
    }
  }

  /**
   * Upgrade contract implementation (owner only)
   */
  async upgradeTo(newImplementation: string): Promise<string> {
    try {
      const tx = await this.contract.upgradeTo(newImplementation);
      const receipt = await tx.wait();
      console.log(`Contract upgraded to: ${newImplementation}`);
      return receipt.transactionHash;
    } catch (error: any) {
      this.handleError(error, 'upgradeTo');
      throw error;
    }
  }

  /**
   * Get contract owner
   */
  async getOwner(): Promise<string> {
    return await this.contract.owner();
  }

  /**
   * Transfer ownership (owner only)
   */
  async transferOwnership(newOwner: string): Promise<string> {
    try {
      const tx = await this.contract.transferOwnership(newOwner);
      const receipt = await tx.wait();
      console.log(`Ownership transferred to: ${newOwner}`);
      return receipt.transactionHash;
    } catch (error: any) {
      this.handleError(error, 'transferOwnership');
      throw error;
    }
  }

  /**
   * Set up event listeners
   */
  onSubmited(callback: (tributeDraftId: string, owner: string, submittedBy: string, cuCount: bigint, timestamp: bigint) => void): void {
    this.contract.on('Submited', (tributeDraftId, owner, submittedBy, cuCount, timestamp, event) => {
      callback(tributeDraftId, owner, submittedBy, cuCount, timestamp);
    });
  }

  onUpgraded(callback: (implementation: string) => void): void {
    this.contract.on('Upgraded', (implementation, event) => {
      callback(implementation);
    });
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }

  /**
   * Generate a tribute draft ID from consumption unit hashes
   * This is how the contract calculates the ID
   */
  static generateTributeDraftId(cuHashes: string[]): string {
    return ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['bytes32[]'], [cuHashes]));
  }

  /**
   * Convert amounts to human readable format
   */
  static formatAmount(base: bigint, atto: bigint): string {
    const wholePart = base.toString();
    const fractionalPart = atto.toString().padStart(18, '0');
    // Remove trailing zeros from fractional part
    const trimmedFractional = fractionalPart.replace(/0+$/, '');
    
    if (trimmedFractional === '') {
      return wholePart;
    }
    
    return `${wholePart}.${trimmedFractional}`;
  }

  /**
   * Validate consumption unit hashes before minting
   */
  static validateConsumptionUnits(cuHashes: string[]): void {
    if (cuHashes.length === 0) {
      throw new Error('At least one consumption unit hash must be provided');
    }

    // Check for duplicates
    const unique = new Set(cuHashes);
    if (unique.size !== cuHashes.length) {
      throw new Error('Duplicate consumption unit hashes provided');
    }

    // Validate hash format
    for (const hash of cuHashes) {
      if (!ethers.isHexString(hash, 32)) {
        throw new Error(`Invalid hash format: ${hash}`);
      }
    }
  }

  /**
   * Handle and format contract errors
   */
  private handleError(error: any, operation: string): void {
    console.error(`TributeDraft ${operation} error:`, error);

    if (error.reason) {
      switch (error.reason) {
        case 'EmptyArray()':
          console.error('Consumption unit array cannot be empty');
          break;
        case 'AlreadyExists()':
          console.error('Duplicate consumption unit hash provided or hash already used in another tribute draft');
          break;
        case 'NotFound(bytes32)':
          console.error('One or more consumption units not found');
          break;
        case 'NotSameOwner()':
          console.error('All consumption units must be owned by the caller');
          break;
        case 'NotSettlementCurrencyCurrency()':
          console.error('All consumption units must have the same settlement currency');
          break;
        case 'NotSameWorldwideDay()':
          console.error('All consumption units must have the same worldwide day');
          break;
        default:
          console.error('Unknown contract error:', error.reason);
      }
    }
  }
}

/**
 * Helper class for working with tribute draft aggregation
 */
export class TributeDraftAggregator {
  /**
   * Validate that consumption units can be aggregated
   * This performs the same checks that the contract will do
   */
  static validateAggregation(consumptionUnits: Array<{
    owner: string;
    settlementCurrency: number;
    worldwideDay: number;
  }>, expectedOwner: string): { valid: boolean; error?: string } {
    if (consumptionUnits.length === 0) {
      return { valid: false, error: 'At least one consumption unit required' };
    }

    // Check owner consistency
    for (const cu of consumptionUnits) {
      if (cu.owner !== expectedOwner) {
        return { valid: false, error: 'All consumption units must have the same owner' };
      }
    }

    // Check currency consistency
    const firstCurrency = consumptionUnits[0].settlementCurrency;
    for (const cu of consumptionUnits) {
      if (cu.settlementCurrency !== firstCurrency) {
        return { valid: false, error: 'All consumption units must have the same settlement currency' };
      }
    }

    // Check day consistency
    const firstDay = consumptionUnits[0].worldwideDay;
    for (const cu of consumptionUnits) {
      if (cu.worldwideDay !== firstDay) {
        return { valid: false, error: 'All consumption units must have the same worldwide day' };
      }
    }

    return { valid: true };
  }

  /**
   * Calculate the total settlement amount for a group of consumption units
   */
  static calculateTotalSettlement(consumptionUnits: Array<{
    settlementAmountBase: bigint;
    settlementAmountAtto: bigint;
  }>): { base: bigint; atto: bigint } {
    let totalBase = 0n;
    let totalAtto = 0n;

    for (const cu of consumptionUnits) {
      totalBase += cu.settlementAmountBase;
      totalAtto += cu.settlementAmountAtto;

      // Handle atto overflow (carry to base)
      if (totalAtto >= BigInt(1e18)) {
        const carryBase = totalAtto / BigInt(1e18);
        totalBase += carryBase;
        totalAtto = totalAtto % BigInt(1e18);
      }
    }

    return { base: totalBase, atto: totalAtto };
  }
}

// Example usage
async function exampleUsage() {
  // Setup
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const userWallet = new Wallet('0x...user-private-key', provider);
  
  // Use proxy address, not implementation address!
  const contractAddress = '0x...tribute-draft-proxy-address';
  
  // Initialize client
  const tdClient = new TributeDraftClient(contractAddress, userWallet, provider);

  try {
    // Build tribute draft parameters
    const mintParams = new TributeDraftBuilder()
      .addConsumptionUnit('0x1111111111111111111111111111111111111111111111111111111111111111')
      .addConsumptionUnit('0x2222222222222222222222222222222222222222222222222222222222222222')
      .addConsumptionUnit('0x3333333333333333333333333333333333333333333333333333333333333333')
      .build();

    // Predict the tribute draft ID
    const predictedId = TributeDraftClient.generateTributeDraftId(mintParams.consumptionUnitHashes);
    console.log('Predicted tribute draft ID:', predictedId);

    // Mint tribute draft
    const mintResult = await tdClient.mint(mintParams);
    console.log('Minted tribute draft:', mintResult.tributeDraftId);
    console.log('Transaction hash:', mintResult.transactionHash);

    // Query the tribute draft
    const tributeDraft = await tdClient.get(mintResult.tributeDraftId);
    if (tributeDraft) {
      console.log('Tribute Draft Details:');
      console.log(`- Owner: ${tributeDraft.owner}`);
      console.log(`- Settlement: ${TributeDraftClient.formatAmount(
        tributeDraft.settlementAmountBase,
        tributeDraft.settlementAmountAtto
      )} (Currency: ${tributeDraft.settlementCurrency})`);
      console.log(`- Day: ${tributeDraft.worldwideDay}`);
      console.log(`- Consumption Units: ${tributeDraft.cuHashes.length}`);
      console.log(`- Created: ${new Date(Number(tributeDraft.submittedAt) * 1000).toISOString()}`);

      // Show individual consumption units
      console.log('Consumption Unit Hashes:');
      tributeDraft.cuHashes.forEach((hash, index) => {
        console.log(`  ${index + 1}. ${hash}`);
      });
    }

    // Set up event monitoring
    tdClient.onSubmited((tributeDraftId, owner, submittedBy, cuCount, timestamp) => {
      console.log(`New tribute draft submitted:`);
      console.log(`  ID: ${tributeDraftId}`);
      console.log(`  Owner: ${owner}`);
      console.log(`  Submitted by: ${submittedBy}`);
      console.log(`  CU count: ${cuCount}`);
      console.log(`  Timestamp: ${timestamp}`);
    });

    // Example with validation
    const consumptionUnits = [
      {
        owner: userWallet.address,
        settlementCurrency: 840, // USD
        worldwideDay: 20240115,
        settlementAmountBase: 100n,
        settlementAmountAtto: 500000000000000000n // 0.5 USD
      },
      {
        owner: userWallet.address,
        settlementCurrency: 840, // USD
        worldwideDay: 20240115,
        settlementAmountBase: 200n,
        settlementAmountAtto: 750000000000000000n // 0.75 USD
      }
    ];

    // Validate aggregation
    const validation = TributeDraftAggregator.validateAggregation(consumptionUnits, userWallet.address);
    if (validation.valid) {
      console.log('Consumption units can be aggregated');
      
      // Calculate total
      const total = TributeDraftAggregator.calculateTotalSettlement(consumptionUnits);
      console.log(`Total settlement: ${TributeDraftClient.formatAmount(total.base, total.atto)} USD`);
    } else {
      console.error('Aggregation validation failed:', validation.error);
    }

  } catch (error) {
    console.error('Example failed:', error);
  }
}