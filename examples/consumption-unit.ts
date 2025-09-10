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
import { Interface, Fragment } from '@ethersproject/abi';

// ConsumptionUnitUpgradeable ABI (key functions only)
const CONSUMPTION_UNIT_ABI = [
  // Core functions
  'function submit(bytes32 cuHash, address owner, string settlementCurrency, string worldwideDay, uint64 settlementBaseAmount, uint128 settlementAttoAmount, uint64 nominalBaseQty, uint128 nominalAttoQty, string nominalCurrency, bytes32[] hashes) external',
  'function submitBatch(bytes32[] cuHashes, address[] owners, string[] settlementCurrencies, string[] worldwideDays, uint64[] settlementBaseAmounts, uint128[] settlementAttoAmounts, uint64[] nominalBaseQtys, uint128[] nominalAttoQtys, string[] nominalCurrencies, bytes32[][] hashesArray) external',
  'function isExists(bytes32 cuHash) external view returns (bool)',
  'function getRecord(bytes32 cuHash) external view returns (tuple(address owner, address submittedBy, string settlementCurrency, string worldwideDay, uint64 settlementBaseAmount, uint128 settlementAttoAmount, uint64 nominalBaseQty, uint128 nominalAttoQty, string nominalCurrency, bytes32[] hashes, uint256 submittedAt))',
  'function getRecordsByOwner(address owner) external view returns (bytes32[])',
  'function setCraRegistry(address _craRegistry) external',
  'function getCraRegistry() external view returns (address)',
  
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
  'error CrAlreadyExists()',
  'error CRANotActive()',
  'error InvalidHash()',
  'error InvalidOwner()',
  'error EmptyBatch()',
  'error BatchSizeTooLarge()',
  'error InvalidCurrency()',
  'error InvalidAmount()',
  'error ArrayLengthMismatch()'
];

/**
 * ConsumptionUnit data structure
 */
export interface ConsumptionUnitEntity {
  owner: string;
  submittedBy: string;
  settlementCurrency: string;
  worldwideDay: string;
  settlementBaseAmount: bigint;
  settlementAttoAmount: bigint;
  nominalBaseQty: bigint;
  nominalAttoQty: bigint;
  nominalCurrency: string;
  hashes: string[];
  submittedAt: bigint;
}

/**
 * Submit parameters for consumption units
 */
export interface ConsumptionUnitParams {
  cuHash: string;
  owner: string;
  settlementCurrency: string;
  worldwideDay: string;
  settlementBaseAmount: bigint;
  settlementAttoAmount: bigint;
  nominalBaseQty: bigint;
  nominalAttoQty: bigint;
  nominalCurrency: string;
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
   * Set settlement currency (ISO 4217 code)
   */
  setSettlementCurrency(currency: string): ConsumptionUnitBuilder {
    this.params.settlementCurrency = currency;
    return this;
  }

  /**
   * Set worldwide day (ISO 8601 date string)
   */
  setWorldwideDay(day: string): ConsumptionUnitBuilder {
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
    this.params.settlementBaseAmount = base;
    this.params.settlementAttoAmount = atto;
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
   * Set nominal quantity with base and atto components
   */
  setNominalQuantity(base: bigint, atto: bigint = 0n): ConsumptionUnitBuilder {
    if (atto >= BigInt(1e18)) {
      throw new Error('Atto quantity must be less than 1e18');
    }
    this.params.nominalBaseQty = base;
    this.params.nominalAttoQty = atto;
    return this;
  }

  /**
   * Set nominal quantity from decimal string
   */
  setNominalQuantityFromDecimal(quantity: string): ConsumptionUnitBuilder {
    const [whole, fractional = '0'] = quantity.split('.');
    const base = BigInt(whole);
    const attoStr = fractional.padEnd(18, '0').slice(0, 18);
    const atto = BigInt(attoStr);
    return this.setNominalQuantity(base, atto);
  }

  /**
   * Set nominal currency (unit of measurement)
   */
  setNominalCurrency(currency: string): ConsumptionUnitBuilder {
    this.params.nominalCurrency = currency;
    return this;
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
    const required = ['cuHash', 'owner', 'settlementCurrency', 'worldwideDay', 'nominalCurrency'];
    for (const field of required) {
      if (!this.params[field as keyof ConsumptionUnitParams]) {
        throw new Error(`Missing required field: ${field}`);
      }
    }

    if (this.params.settlementBaseAmount === undefined) {
      throw new Error('Settlement amount must be set');
    }

    if (this.params.nominalBaseQty === undefined) {
      throw new Error('Nominal quantity must be set');
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
        params.settlementBaseAmount,
        params.settlementAttoAmount,
        params.nominalBaseQty,
        params.nominalAttoQty,
        params.nominalCurrency,
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
      const settlementCurrencies = units.map(u => u.settlementCurrency);
      const worldwideDays = units.map(u => u.worldwideDay);
      const settlementBaseAmounts = units.map(u => u.settlementBaseAmount);
      const settlementAttoAmounts = units.map(u => u.settlementAttoAmount);
      const nominalBaseQtys = units.map(u => u.nominalBaseQty);
      const nominalAttoQtys = units.map(u => u.nominalAttoQty);
      const nominalCurrencies = units.map(u => u.nominalCurrency);
      const hashesArray = units.map(u => u.consumptionRecordHashes);

      const tx = await this.contract.submitBatch(
        cuHashes,
        owners,
        settlementCurrencies,
        worldwideDays,
        settlementBaseAmounts,
        settlementAttoAmounts,
        nominalBaseQtys,
        nominalAttoQtys,
        nominalCurrencies,
        hashesArray
      );

      const receipt = await tx.wait();
      console.log(`Batch of ${units.length} consumption units submitted`);
      return receipt.transactionHash;
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
      const result = await this.contract.getRecord(cuHash);
      
      // Check if record exists (submittedBy will be zero address if not found)
      if (result.submittedBy === ethers.ZeroAddress) {
        return null;
      }

      return {
        owner: result.owner,
        submittedBy: result.submittedBy,
        settlementCurrency: result.settlementCurrency,
        worldwideDay: result.worldwideDay,
        settlementBaseAmount: result.settlementBaseAmount,
        settlementAttoAmount: result.settlementAttoAmount,
        nominalBaseQty: result.nominalBaseQty,
        nominalAttoQty: result.nominalAttoQty,
        nominalCurrency: result.nominalCurrency,
        hashes: result.hashes,
        submittedAt: result.submittedAt
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
      return await this.contract.getRecordsByOwner(owner);
    } catch (error: any) {
      this.handleError(error, 'getRecordsByOwner');
      throw error;
    }
  }

  /**
   * Get CRA Registry address
   */
  async getCraRegistry(): Promise<string> {
    return await this.contract.getCraRegistry();
  }

  /**
   * Set CRA Registry address (owner only)
   */
  async setCraRegistry(craRegistryAddress: string): Promise<string> {
    try {
      const tx = await this.contract.setCraRegistry(craRegistryAddress);
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
        case 'CrAlreadyExists()':
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
        case 'InvalidCurrency()':
          console.error('Invalid currency code provided');
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
      .setSettlementCurrency('USD')
      .setWorldwideDay('2024-01-15')
      .setSettlementAmountFromDecimal('150.75')  // $150.75
      .setNominalQuantityFromDecimal('100.5')    // 100.5 kWh
      .setNominalCurrency('kWh')
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
      console.log(`- Settlement: ${ConsumptionUnitClient.formatAmount(unit.settlementBaseAmount, unit.settlementAttoAmount)} ${unit.settlementCurrency}`);
      console.log(`- Nominal: ${ConsumptionUnitClient.formatAmount(unit.nominalBaseQty, unit.nominalAttoQty)} ${unit.nominalCurrency}`);
      console.log(`- Day: ${unit.worldwideDay}`);
      console.log(`- CR Hashes: ${unit.hashes.length} records`);
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

export {
  ConsumptionUnitClient,
  ConsumptionUnitBuilder,
  type ConsumptionUnitEntity,
  type ConsumptionUnitParams
};