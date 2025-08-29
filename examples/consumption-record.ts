import { ethers, Contract, Wallet, Provider } from 'ethers';

// Consumption Record ABI - generated from the contract
const CONSUMPTION_RECORD_ABI = [
  "function submit(bytes32 crHash, string[] memory keys, string[] memory values) external",
  "function isExists(bytes32 crHash) external view returns (bool)",
  "function getDetails(bytes32 crHash) external view returns (tuple(address submittedBy, uint256 submittedAt))",
  "function getMetadata(bytes32 crHash, string memory key) external view returns (string memory)",
  "function getMetadataKeys(bytes32 crHash) external view returns (string[] memory)",
  "function setCraRegistry(address _craRegistry) external",
  "function getCraRegistry() external view returns (address)",
  "function getOwner() external view returns (address)",
  "event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp)",
  "event MetadataAdded(bytes32 indexed crHash, string key, string value)"
];

export interface CRRecord {
  submittedBy: string;
  submittedAt: bigint;
}

export interface ConsumptionMetadata {
  [key: string]: string;
}

export class ConsumptionRecordClient {
  private contract: Contract;
  private signer: Wallet;

  constructor(
    contractAddress: string,
    signer: Wallet,
    provider: Provider
  ) {
    this.signer = signer.connect(provider);
    this.contract = new Contract(contractAddress, CONSUMPTION_RECORD_ABI, this.signer);
  }

  /**
   * Submit a consumption record with metadata (active CRA only)
   */
  async submit(
    crHash: string,
    metadata: ConsumptionMetadata
  ): Promise<void> {
    const keys = Object.keys(metadata);
    const values = Object.values(metadata);

    try {
      const tx = await this.contract.submit(crHash, keys, values);
      await tx.wait();
      console.log(`✅ Consumption record submitted: ${crHash}`);
    } catch (error: any) {
      if (error.message.includes('AlreadyExists')) {
        throw new Error(`Consumption record ${crHash} already exists`);
      } else if (error.message.includes('CRANotActive')) {
        throw new Error('Only active CRAs can submit consumption records');
      } else if (error.message.includes('InvalidHash')) {
        throw new Error('Invalid consumption record hash');
      } else if (error.message.includes('MetadataKeyValueMismatch')) {
        throw new Error('Metadata keys and values arrays must have the same length');
      } else if (error.message.includes('EmptyMetadataKey')) {
        throw new Error('Metadata keys cannot be empty');
      }
      throw error;
    }
  }

  /**
   * Check if a consumption record exists
   */
  async isExists(crHash: string): Promise<boolean> {
    return await this.contract.isExists(crHash);
  }

  /**
   * Get consumption record details
   */
  async getDetails(crHash: string): Promise<CRRecord> {
    const result = await this.contract.getDetails(crHash);
    return {
      submittedBy: result.submittedBy,
      submittedAt: result.submittedAt
    };
  }

  /**
   * Get specific metadata value for a consumption record
   */
  async getMetadata(crHash: string, key: string): Promise<string> {
    return await this.contract.getMetadata(crHash, key);
  }

  /**
   * Get all metadata keys for a consumption record
   */
  async getMetadataKeys(crHash: string): Promise<string[]> {
    return await this.contract.getMetadataKeys(crHash);
  }

  /**
   * Get all metadata for a consumption record
   */
  async getAllMetadata(crHash: string): Promise<ConsumptionMetadata> {
    const keys = await this.getMetadataKeys(crHash);
    const metadata: ConsumptionMetadata = {};
    
    for (const key of keys) {
      metadata[key] = await this.getMetadata(crHash, key);
    }
    
    return metadata;
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
  async setCraRegistry(registryAddress: string): Promise<void> {
    try {
      const tx = await this.contract.setCraRegistry(registryAddress);
      await tx.wait();
      console.log(`✅ CRA Registry updated: ${registryAddress}`);
    } catch (error: any) {
      if (error.message.includes('CRANotActive')) {
        throw new Error('Only contract owner can set CRA Registry');
      }
      throw error;
    }
  }

  /**
   * Get contract owner address
   */
  async getOwner(): Promise<string> {
    return await this.contract.getOwner();
  }

  /**
   * Listen for consumption record submission events
   */
  onSubmitted(callback: (crHash: string, cra: string, timestamp: bigint) => void): void {
    this.contract.on('Submitted', callback);
  }

  /**
   * Listen for metadata addition events
   */
  onMetadataAdded(callback: (crHash: string, key: string, value: string) => void): void {
    this.contract.on('MetadataAdded', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }

  /**
   * Generate a consumption record hash from data
   */
  static generateHash(data: any): string {
    return ethers.keccak256(ethers.toUtf8Bytes(JSON.stringify(data)));
  }

  /**
   * Validate consumption record hash format
   */
  static isValidHash(hash: string): boolean {
    return ethers.isHexString(hash, 32) && hash !== '0x0000000000000000000000000000000000000000000000000000000000000000';
  }
}

// Helper class for building consumption record metadata
export class ConsumptionMetadataBuilder {
  private metadata: ConsumptionMetadata = {};

  /**
   * Add energy source information
   */
  setSource(source: string): this {
    this.metadata['source'] = source;
    return this;
  }

  /**
   * Add energy amount consumed
   */
  setAmount(amount: string): this {
    this.metadata['amount'] = amount;
    return this;
  }

  /**
   * Add unit of measurement
   */
  setUnit(unit: string): this {
    this.metadata['unit'] = unit;
    return this;
  }

  /**
   * Add timestamp of consumption
   */
  setTimestamp(timestamp: string | number): this {
    this.metadata['timestamp'] = timestamp.toString();
    return this;
  }

  /**
   * Add location information
   */
  setLocation(location: string): this {
    this.metadata['location'] = location;
    return this;
  }

  /**
   * Add renewable energy percentage
   */
  setRenewablePercentage(percentage: string): this {
    this.metadata['renewable_percentage'] = percentage;
    return this;
  }

  /**
   * Add carbon footprint data
   */
  setCarbonFootprint(footprint: string): this {
    this.metadata['carbon_footprint'] = footprint;
    return this;
  }

  /**
   * Add custom metadata field
   */
  setCustom(key: string, value: string): this {
    if (!key || key.trim() === '') {
      throw new Error('Metadata key cannot be empty');
    }
    this.metadata[key] = value;
    return this;
  }

  /**
   * Build the metadata object
   */
  build(): ConsumptionMetadata {
    return { ...this.metadata };
  }

  /**
   * Clear all metadata
   */
  clear(): this {
    this.metadata = {};
    return this;
  }
}

// Example usage
export async function exampleUsage() {
  // Setup
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const wallet = new Wallet('0x...your-private-key', provider);
  const contractAddress = '0x...contract-address';
  
  const consumptionRecord = new ConsumptionRecordClient(contractAddress, wallet, provider);

  try {
    // Create consumption data
    const consumptionData = {
      deviceId: 'smart-meter-001',
      timestamp: Date.now(),
      amount: 150.5,
      source: 'solar'
    };

    // Generate hash for the consumption record
    const crHash = ConsumptionRecordClient.generateHash(consumptionData);
    console.log('Generated hash:', crHash);

    // Validate hash
    if (!ConsumptionRecordClient.isValidHash(crHash)) {
      throw new Error('Invalid hash generated');
    }

    // Build metadata using the builder
    const metadata = new ConsumptionMetadataBuilder()
      .setSource('renewable')
      .setAmount('150.5')
      .setUnit('kWh')
      .setTimestamp(Date.now())
      .setLocation('San Francisco, CA')
      .setRenewablePercentage('85')
      .setCarbonFootprint('0.12')
      .setCustom('device_id', 'smart-meter-001')
      .setCustom('grid_operator', 'PG&E')
      .build();

    console.log('Metadata to submit:', metadata);

    // Submit the consumption record
    await consumptionRecord.submit(crHash, metadata);

    // Verify the record exists
    const exists = await consumptionRecord.isExists(crHash);
    console.log('Record exists:', exists);

    // Get record details
    const details = await consumptionRecord.getDetails(crHash);
    console.log('Record details:', {
      submittedBy: details.submittedBy,
      submittedAt: new Date(Number(details.submittedAt) * 1000)
    });

    // Get all metadata
    const retrievedMetadata = await consumptionRecord.getAllMetadata(crHash);
    console.log('Retrieved metadata:', retrievedMetadata);

    // Get specific metadata values
    const source = await consumptionRecord.getMetadata(crHash, 'source');
    const amount = await consumptionRecord.getMetadata(crHash, 'amount');
    console.log(`Energy source: ${source}, Amount: ${amount}`);

    // Listen for events
    consumptionRecord.onSubmitted((crHash, cra, timestamp) => {
      console.log(`🔔 New consumption record: ${crHash} by ${cra}`);
    });

    consumptionRecord.onMetadataAdded((crHash, key, value) => {
      console.log(`🔔 Metadata added to ${crHash}: ${key} = ${value}`);
    });

  } catch (error) {
    console.error('Error:', error);
  }
}