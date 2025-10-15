/**
 * Outbe L2 - ConsumptionUnitUpgradeable TypeScript Integration Example
 * 
 * This example demonstrates how to interact with the ConsumptionUnitUpgradeable contract
 * using ethers.js. ConsumptionUnits aggregate ConsumptionRecords into settlement units 
 * with currency amounts and nominal quantities.
 * 
 * Features:
 * - Submit individual consumption units (CRA only)
 * - Submit batches of consumption units (CRA only) 
 * - Query consumption unit details
 * - Get consumption units by owner
 * - Event monitoring for submissions
 * - UUPS upgrade functionality
 * 
 * @author Outbe Team
 * @version 1.0.0
 */

import { ethers, Contract, Wallet, Provider } from 'ethers';

// ConsumptionUnitUpgradeable ABI (key functions only)
const CONSUMPTION_UNIT_ABI = [
  // Core functions
  'function submit(bytes32 cuHash, address owner, uint16 settlementCurrency, uint32 worldwideDay, uint64 settlementAmountBase, uint128 settlementAmountAtto, bytes32[] hashes) external',
  'function submitBatch(bytes32[] cuHashes, address[] owners, uint32[] worldwideDays, uint16[] settlementCurrencies, uint64[] settlementAmountsBase, uint128[] settlementAmountsAtto, bytes32[][] crHashesArray) external',
  'function isExists(bytes32 cuHash) external view returns (bool)',
  'function getConsumptionUnit(bytes32 cuHash) external view returns (tuple(bytes32 consumptionUnitId, address owner, address submittedBy, uint256 submittedAt, uint32 worldwideDay, uint64 settlementAmountBase, uint128 settlementAmountAtto, uint16 settlementCurrency, bytes32[] crHashes))',
  'function getConsumptionUnitsByOwner(address owner) external view returns (bytes32[])',
  'function setCRARegistry(address _craRegistry) external',
  'function getCRARegistry() external view returns (address)',
  
  // Upgrade functions (owner only)
  'function upgradeTo(address newImplementation) external',
  'function upgradeToAndCall(address newImplementation, bytes data) external payable',
  
  // Ownable functions
  'function owner() external view returns (address)',
  'function transferOwnership(address newOwner) external',
  
  // Events
  'event Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp)',
  'event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp)',
  'event Upgraded(address indexed implementation)',
  
  // Errors
  'error AlreadyExists()',
  'error ConsumptionRecordAlreadyExists()',
  'error CRANotActive()',
  'error InvalidHash()',
  'error InvalidOwner()',
  'error EmptyBatch()',
  'error BatchSizeTooLarge()',
  'error InvalidSettlementCurrency()',
  'error InvalidAmount()',
  'error ArrayLengthMismatch()'
];

/**
 * ConsumptionUnit data structure
 */
export interface ConsumptionUnitEntity {
  consumptionUnitId: string;
  owner: string;
  submittedBy: string;
  submittedAt: bigint;
  worldwideDay: number; // uint32 from contract
  settlementAmountBase: bigint; // uint64 from contract
  settlementAmountAtto: bigint; // uint128 from contract
  settlementCurrency: number; // uint16 from contract
  crHashes: string[];
}

/**
 * Submit parameters for consumption units
 */
export interface ConsumptionUnitParams {
  cuHash: string;
  owner: string;
  settlementCurrency: number; // uint16 - ISO 4217 numeric code
  worldwideDay: number; // uint32 - YYYYMMDD format
  settlementAmountBase: bigint; // uint64 - base units
  settlementAmountAtto: bigint; // uint128 - fractional units (< 1e18)
  consumptionRecordHashes: string[];
}

/**
 * Builder for constructing consumption unit parameters
 */
export class ConsumptionUnitBuilder {
  private params: Partial<ConsumptionUnitParams> = {};

  /**
   * Set the consumption unit hash (unique identifier)
   */
  setCuHash(cuHash: string): ConsumptionUnitBuilder {
    this.params.cuHash = cuHash;
    return this;
  }

  /**
   * Set the owner address
   */
  setOwner(owner: string): ConsumptionUnitBuilder {
    this.params.owner = owner;
    return this;
  }

  /**
   * Set settlement currency (ISO 4217 numeric code)
   */
  setSettlementCurrency(currency: number): ConsumptionUnitBuilder {
    this.params.settlementCurrency = currency;
    return this;
  }

  /**
   * Set worldwide day (ISO 8601 numeric format YYYYMMDD)
   */
  setWorldwideDay(day: number): ConsumptionUnitBuilder {
    this.params.worldwideDay = day;
    return this;
  }

  /**
   * Set settlement amount with base and atto components
   * @param base - Natural units (e.g., whole dollars)
   * @param atto - Fractional units (must be < 1e18)
   */
  setSettlementAmount(base: bigint, atto: bigint = 0n): ConsumptionUnitBuilder {
    if (atto >= BigInt(1e18)) {
      throw new Error('Atto amount must be less than 1e18');
    }
    this.params.settlementAmountBase = base;
    this.params.settlementAmountAtto = atto;
    return this;
  }

  /**
   * Set settlement amount from decimal string (e.g., "123.456")
   */
  setSettlementAmountFromDecimal(amount: string): ConsumptionUnitBuilder {
    const [whole, fractional = '0'] = amount.split('.');
    const base = BigInt(whole);
    // Convert fractional part to atto (18 decimals)
    const attoStr = fractional.padEnd(18, '0').slice(0, 18);
    const atto = BigInt(attoStr);
    return this.setSettlementAmount(base, atto);
  }

  /**
   * Set consumption record hashes
   */
  setConsumptionRecordHashes(hashes: string[]): ConsumptionUnitBuilder {
    this.params.consumptionRecordHashes = hashes;
    return this;
  }

  /**
   * Add a single consumption record hash
   */
  addConsumptionRecordHash(hash: string): ConsumptionUnitBuilder {
    if (!this.params.consumptionRecordHashes) {
      this.params.consumptionRecordHashes = [];
    }
    this.params.consumptionRecordHashes.push(hash);
    return this;
  }

  /**
   * Build the consumption unit parameters
   */
  build(): ConsumptionUnitParams {
    const required = ['cuHash', 'owner', 'settlementCurrency', 'worldwideDay'];
    for (const field of required) {
      if (!this.params[field as keyof ConsumptionUnitParams]) {
        throw new Error(`Missing required field: ${field}`);
      }
    }

    if (this.params.settlementAmountBase === undefined) {
      throw new Error('Settlement amount must be set');
    }

    if (!this.params.consumptionRecordHashes?.length) {
      throw new Error('At least one consumption record hash must be provided');
    }

    return this.params as ConsumptionUnitParams;
  }
}

/**
 * ConsumptionUnit contract client with full functionality
 */
export class ConsumptionUnitClient {
  private contract: Contract;
  private signer: Wallet;
  private provider: Provider;

  constructor(contractAddress: string, signer: Wallet, provider: Provider) {
    this.contract = new Contract(contractAddress, CONSUMPTION_UNIT_ABI, signer);
    this.signer = signer;
    this.provider = provider;
  }

  /**
   * Submit a single consumption unit (requires active CRA status)
   */
  async submit(params: ConsumptionUnitParams): Promise<string> {
    try {
      const tx = await this.contract.submit(
        params.cuHash,
        params.owner,
        params.settlementCurrency,
        params.worldwideDay,
        params.settlementAmountBase,
        params.settlementAmountAtto,
        params.consumptionRecordHashes
      );

      const receipt = await tx.wait();
      console.log(`Consumption unit submitted: ${params.cuHash}`);
      return receipt.transactionHash;
    } catch (error: any) {
      this.handleError(error, 'submit');
      throw error;
    }
  }

  /**
   * Submit multiple consumption units in batch (requires active CRA status)
   */
  async submitBatch(units: ConsumptionUnitParams[]): Promise<string> {
    if (units.length === 0) {
      throw new Error('Batch cannot be empty');
    }

    if (units.length > 100) {
      throw new Error('Batch size cannot exceed 100');
    }

    try {
      const cuHashes = units.map(u => u.cuHash);
      const owners = units.map(u => u.owner);
      const worldwideDays = units.map(u => u.worldwideDay);
      const settlementCurrencies = units.map(u => u.settlementCurrency);
      const settlementAmountsBase = units.map(u => u.settlementAmountBase);
      const settlementAmountsAtto = units.map(u => u.settlementAmountAtto);
      const crHashesArray = units.map(u => u.consumptionRecordHashes);

      const tx = await this.contract.submitBatch(
        cuHashes,
        owners,
        worldwideDays,
        settlementCurrencies,
        settlementAmountsBase,
        settlementAmountsAtto,
        crHashesArray
      );

      const receipt = await tx.wait();
      console.log(`Batch of ${units.length} consumption units submitted`);
      return receipt.hash;
    } catch (error: any) {
      this.handleError(error, 'submitBatch');
      throw error;
    }
  }

  /**
   * Check if a consumption unit exists
   */
  async isExists(cuHash: string): Promise<boolean> {
    try {
      return await this.contract.isExists(cuHash);
    } catch (error: any) {
      this.handleError(error, 'isExists');
      throw error;
    }
  }

  /**
   * Get consumption unit details
   */
  async getRecord(cuHash: string): Promise<ConsumptionUnitEntity | null> {
    try {
      const result = await this.contract.getConsumptionUnit(cuHash);

      // Check if record exists (submittedBy will be zero address if not found)
      if (result.submittedBy === ethers.ZeroAddress) {
        return null;
      }

      return {
        consumptionUnitId: result.consumptionUnitId,
        owner: result.owner,
        submittedBy: result.submittedBy,
        submittedAt: result.submittedAt,
        worldwideDay: result.worldwideDay,
        settlementAmountBase: result.settlementAmountBase,
        settlementAmountAtto: result.settlementAmountAtto,
        settlementCurrency: result.settlementCurrency,
        crHashes: result.crHashes
      };
    } catch (error: any) {
      this.handleError(error, 'getRecord');
      throw error;
    }
  }

  /**
   * Get all consumption unit hashes owned by an address
   */
  async getRecordsByOwner(owner: string): Promise<string[]> {
    try {
      return await this.contract.getConsumptionUnitsByOwner(owner);
    } catch (error: any) {
      this.handleError(error, 'getRecordsByOwner');
      throw error;
    }
  }

  /**
   * Get CRA Registry address
   */
  async getCraRegistry(): Promise<string> {
    return await this.contract.getCRARegistry();
  }

  /**
   * Set CRA Registry address (owner only)
   */
  async setCraRegistry(craRegistryAddress: string): Promise<string> {
    try {
      const tx = await this.contract.setCRARegistry(craRegistryAddress);
      const receipt = await tx.wait();
      console.log(`CRA Registry updated: ${craRegistryAddress}`);
      return receipt.transactionHash;
    } catch (error: any) {
      this.handleError(error, 'setCraRegistry');
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
  onSubmitted(callback: (cuHash: string, cra: string, timestamp: bigint) => void): void {
    this.contract.on('Submitted', (cuHash, cra, timestamp, event) => {
      callback(cuHash, cra, timestamp);
    });
  }

  onBatchSubmitted(callback: (batchSize: bigint, cra: string, timestamp: bigint) => void): void {
    this.contract.on('BatchSubmitted', (batchSize, cra, timestamp, event) => {
      callback(batchSize, cra, timestamp);
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
   * Generate a consumption unit hash from input parameters
   */
  static generateHash(input: {
    owner: string;
    settlementData: string;
    worldwideDay: string;
    consumptionRecordHashes: string[];
  }): string {
    const data = ethers.solidityPacked(
      ['address', 'string', 'string', 'bytes32[]'],
      [input.owner, input.settlementData, input.worldwideDay, input.consumptionRecordHashes]
    );
    return ethers.keccak256(data);
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
   * Parse decimal amount into base and atto components
   */
  static parseAmount(amount: string): { base: bigint; atto: bigint } {
    const [whole = '0', fractional = '0'] = amount.split('.');
    const base = BigInt(whole);
    const attoStr = fractional.padEnd(18, '0').slice(0, 18);
    const atto = BigInt(attoStr);
    
    return { base, atto };
  }

  /**
   * Handle and format contract errors
   */
  private handleError(error: any, operation: string): void {
    console.error(`ConsumptionUnit ${operation} error:`, error);

    if (error.reason) {
      switch (error.reason) {
        case 'AlreadyExists()':
          console.error('Consumption unit already exists');
          break;
        case 'ConsumptionRecordAlreadyExists()':
          console.error('One of the consumption record hashes already exists');
          break;
        case 'CRANotActive()':
          console.error('CRA is not active - only active CRAs can submit');
          break;
        case 'InvalidHash()':
          console.error('Invalid consumption unit hash provided');
          break;
        case 'InvalidOwner()':
          console.error('Invalid owner address provided');
          break;
        case 'InvalidSettlementCurrency()':
          console.error('Invalid settlement currency code provided');
          break;
        case 'InvalidAmount()':
          console.error('Invalid amount - atto component must be < 1e18');
          break;
        case 'EmptyBatch()':
          console.error('Batch cannot be empty');
          break;
        case 'BatchSizeTooLarge()':
          console.error('Batch size exceeds maximum of 100');
          break;
        case 'ArrayLengthMismatch()':
          console.error('Input arrays must have the same length');
          break;
        default:
          console.error('Unknown contract error:', error.reason);
      }
    }
  }
}

// Example usage
async function exampleUsage() {
  // Setup
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const ownerWallet = new Wallet('0x...owner-private-key', provider);
  const craWallet = new Wallet('0x...cra-private-key', provider);
  
  // Use proxy address, not implementation address!
  const contractAddress = '0x...consumption-unit-proxy-address';
  
  // Initialize client with CRA wallet (for submissions)
  const cuClient = new ConsumptionUnitClient(contractAddress, craWallet, provider);

  try {
    // Build a consumption unit
    const cuParams = new ConsumptionUnitBuilder()
      .setCuHash('0x1234567890123456789012345678901234567890123456789012345678901234')
      .setOwner(ownerWallet.address)
      .setSettlementCurrency(840)  // USD ISO 4217 numeric code
      .setWorldwideDay(20240115)   // 2024-01-15 as YYYYMMDD
      .setSettlementAmountFromDecimal('150.75')  // $150.75
      .addConsumptionRecordHash('0xabcd1234567890123456789012345678901234567890123456789012345678ab')
      .addConsumptionRecordHash('0xabcd1234567890123456789012345678901234567890123456789012345678cd')
      .build();

    // Submit consumption unit
    const txHash = await cuClient.submit(cuParams);
    console.log('Consumption unit submitted:', txHash);

    // Query the consumption unit
    const unit = await cuClient.getRecord(cuParams.cuHash);
    if (unit) {
      console.log('Consumption Unit Details:');
      console.log(`- Owner: ${unit.owner}`);
      console.log(`- Settlement: ${ConsumptionUnitClient.formatAmount(unit.settlementAmountBase, unit.settlementAmountAtto)} (Currency: ${unit.settlementCurrency})`);
      console.log(`- Day: ${unit.worldwideDay}`);
      console.log(`- CR Hashes: ${unit.crHashes.length} records`);
    }

    // Get all units for owner
    const ownerUnits = await cuClient.getRecordsByOwner(ownerWallet.address);
    console.log(`Owner has ${ownerUnits.length} consumption units`);

    // Set up event monitoring
    cuClient.onSubmitted((cuHash, cra, timestamp) => {
      console.log(`New consumption unit: ${cuHash} from CRA: ${cra}`);
    });

  } catch (error) {
    console.error('Example failed:', error);
  }
}
