import { ethers, Contract, Wallet, Provider } from 'ethers';

// ConsumptionRecordUpgradeable ABI - generated from the upgradeable contract  
const CONSUMPTION_RECORD_ABI = [
  // Initialization (only called once during deployment)
  "function initialize(address _craRegistry, address _owner) external",
  
  // Single submission
  "function submit(bytes32 crHash, address owner, string[] memory keys, bytes32[] memory values) external",
  
  // Batch submission
  "function submitBatch(bytes32[] memory crHashes, address[] memory owners, string[][] memory keysArray, bytes32[][] memory valuesArray) external",
  
  // Query functions
  "function isExists(bytes32 crHash) external view returns (bool)",
  "function getConsumptionRecord(bytes32 crHash) external view returns (tuple(bytes32 consumptionRecordId, address submittedBy, uint256 submittedAt, address owner, string[] metadataKeys, bytes32[] metadataValues))",
  "function getConsumptionRecordsByOwner(address owner) external view returns (bytes32[] memory)",

  // Admin functions
  "function setCRARegistry(address _craRegistry) external",
  "function getCRARegistry() external view returns (address)",
  "function getOwner() external view returns (address)",
  
  // Upgrade functions (owner only)
  "function upgradeTo(address newImplementation) external",
  "function upgradeToAndCall(address newImplementation, bytes calldata data) external payable",
  
  // Constants
  "function MAX_BATCH_SIZE() external view returns (uint256)",
  "function VERSION() external view returns (string)",
  
  // Events
  "event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp)",
  "event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp)"
];

export interface CRRecord {
  consumptionRecordId: string;
  submittedBy: string;
  submittedAt: bigint;
  owner: string;
  metadataKeys: string[];
  metadataValues: string[]; // bytes32[] from contract, converted to string[] for convenience
}

export interface ConsumptionMetadata {
  [key: string]: string;
}

export interface BatchSubmissionRequest {
  crHash: string;
  owner: string;
  metadata: ConsumptionMetadata;
}

export interface BatchSubmissionResult {
  success: boolean;
  batchSize: number;
  transactionHash: string;
  submittedRecords: string[];
}

export class ConsumptionRecordClient {
  public contract: Contract;
  public signer: Wallet;

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
    owner: string,
    metadata: ConsumptionMetadata
  ): Promise<void> {
    const keys = Object.keys(metadata);
    const values = Object.values(metadata).map(v => ConsumptionRecordClient.stringToBytes32(v));

    try {
      const tx = await this.contract.submit(crHash, owner, keys, values);
      await tx.wait();
      console.log(`✅ Consumption record submitted: ${crHash} (owner: ${owner})`);
    } catch (error: any) {
      this.handleSubmissionError(error, crHash);
    }
  }

  /**
   * Submit multiple consumption records in a single transaction (active CRA only)
   */
  async submitBatch(requests: BatchSubmissionRequest[]): Promise<BatchSubmissionResult> {
    if (requests.length === 0) {
      throw new Error('Batch cannot be empty');
    }

    // Check maximum batch size
    const maxBatchSize = await this.contract.MAX_BATCH_SIZE();
    if (requests.length > Number(maxBatchSize)) {
      throw new Error(`Batch size ${requests.length} exceeds maximum ${maxBatchSize}`);
    }

    // Prepare batch data
    const crHashes = requests.map(req => req.crHash);
    const owners = requests.map(req => req.owner);
    const keysArray = requests.map(req => Object.keys(req.metadata));
    const valuesArray = requests.map(req =>
      Object.values(req.metadata).map(v => ConsumptionRecordClient.stringToBytes32(v))
    );

    try {
      const tx = await this.contract.submitBatch(crHashes, owners, keysArray, valuesArray);
      const receipt = await tx.wait();

      console.log(`✅ Batch submitted: ${requests.length} records`);
      
      return {
        success: true,
        batchSize: requests.length,
        transactionHash: receipt.hash,
        submittedRecords: crHashes
      };
    } catch (error: any) {
      if (error.message.includes('BatchSizeTooLarge')) {
        throw new Error(`Batch size exceeds maximum allowed (${maxBatchSize})`);
      } else if (error.message.includes('EmptyBatch')) {
        throw new Error('Cannot submit empty batch');
      }
      this.handleSubmissionError(error);
      throw error; // This won't be reached due to handleSubmissionError throwing
    }
  }

  /**
   * Handle common submission errors
   */
  private handleSubmissionError(error: any, crHash?: string): never {
    const hashInfo = crHash ? ` (${crHash})` : '';
    
    if (error.message.includes('AlreadyExists')) {
      throw new Error(`Consumption record${hashInfo} already exists`);
    } else if (error.message.includes('CRANotActive')) {
      throw new Error('Only active CRAs can submit consumption records');
    } else if (error.message.includes('InvalidHash')) {
      throw new Error(`Invalid consumption record hash${hashInfo}`);
    } else if (error.message.includes('InvalidOwner')) {
      throw new Error('Invalid owner address (cannot be zero address)');
    } else if (error.message.includes('MetadataKeyValueMismatch')) {
      throw new Error('Metadata keys and values arrays must have the same length');
    } else if (error.message.includes('EmptyMetadataKey')) {
      throw new Error('Metadata keys cannot be empty');
    }
    throw error;
  }

  /**
   * Check if a consumption record exists
   */
  async isExists(crHash: string): Promise<boolean> {
    return await this.contract.isExists(crHash);
  }

  /**
   * Get complete consumption record data
   */
  async getRecord(crHash: string): Promise<CRRecord> {
    const result = await this.contract.getConsumptionRecord(crHash);
    return {
      consumptionRecordId: result.consumptionRecordId,
      submittedBy: result.submittedBy,
      submittedAt: result.submittedAt,
      owner: result.owner,
      metadataKeys: result.metadataKeys,
      metadataValues: result.metadataValues.map((v: string) => ConsumptionRecordClient.bytes32ToString(v))
    };
  }

  /**
   * Get all consumption record hashes owned by a specific address
   */
  async getRecordsByOwner(owner: string): Promise<string[]> {
    return await this.contract.getConsumptionRecordsByOwner(owner);
  }

  /**
   * Get complete records for a specific owner
   */
  async getCompleteRecordsByOwner(owner: string): Promise<CRRecord[]> {
    const hashes = await this.getRecordsByOwner(owner);
    const records: CRRecord[] = [];
    
    for (const hash of hashes) {
      const record = await this.getRecord(hash);
      records.push(record);
    }
    
    return records;
  }

  /**
   * Get metadata as key-value object from a record
   */
  getMetadataFromRecord(record: CRRecord): ConsumptionMetadata {
    const metadata: ConsumptionMetadata = {};
    
    for (let i = 0; i < record.metadataKeys.length; i++) {
      metadata[record.metadataKeys[i]] = record.metadataValues[i];
    }
    
    return metadata;
  }

  /**
   * Get specific metadata value from a record
   */
  getMetadataValue(record: CRRecord, key: string): string | undefined {
    const index = record.metadataKeys.indexOf(key);
    return index !== -1 ? record.metadataValues[index] : undefined;
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
  async setCraRegistry(registryAddress: string): Promise<void> {
    try {
      const tx = await this.contract.setCRARegistry(registryAddress);
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
   * Upgrade contract to new implementation (owner only)
   */
  async upgradeTo(newImplementation: string): Promise<void> {
    try {
      const tx = await this.contract.upgradeTo(newImplementation);
      await tx.wait();
      console.log(`✅ Contract upgraded to: ${newImplementation}`);
    } catch (error: any) {
      if (error.message.includes('Ownable')) {
        throw new Error('Only contract owner can upgrade the contract');
      }
      throw error;
    }
  }

  /**
   * Upgrade contract and call function in single transaction (owner only)
   */
  async upgradeToAndCall(newImplementation: string, calldata: string): Promise<void> {
    try {
      const tx = await this.contract.upgradeToAndCall(newImplementation, calldata);
      await tx.wait();
      console.log(`✅ Contract upgraded to ${newImplementation} with call data`);
    } catch (error: any) {
      if (error.message.includes('Ownable')) {
        throw new Error('Only contract owner can upgrade the contract');
      }
      throw error;
    }
  }

  /**
   * Get contract version
   */
  async getVersion(): Promise<string> {
    return await this.contract.VERSION();
  }

  /**
   * Listen for consumption record submission events
   */
  onSubmitted(callback: (crHash: string, cra: string, timestamp: bigint) => void): void {
    this.contract.on('Submitted', callback);
  }

  /**
   * Listen for batch submission events
   */
  onBatchSubmitted(callback: (batchSize: bigint, cra: string, timestamp: bigint) => void): void {
    this.contract.on('BatchSubmitted', callback);
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

  /**
   * Convert string to bytes32 for metadata values
   */
  static stringToBytes32(str: string): string {
    // Encode string to UTF-8 bytes
    const bytes = ethers.toUtf8Bytes(str);
    // Pad to 32 bytes with zeros
    const padded = new Uint8Array(32);
    padded.set(bytes.slice(0, 32)); // Take first 32 bytes if string is longer
    return ethers.hexlify(padded);
  }

  /**
   * Convert bytes32 back to string
   */
  static bytes32ToString(bytes32: string): string {
    // Remove trailing null bytes
    const bytes = ethers.getBytes(bytes32);
    const endIndex = bytes.findIndex(b => b === 0);
    const trimmedBytes = endIndex === -1 ? bytes : bytes.slice(0, endIndex);
    return ethers.toUtf8String(trimmedBytes);
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
  // Setup - IMPORTANT: Use proxy address, not implementation address!
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const wallet = new Wallet('0x...your-private-key', provider);
  const proxyAddress = '0x...proxy-contract-address'; // Always use proxy address
  const recordOwner = '0x...owner-address'; // The actual owner of consumption records
  
  const consumptionRecord = new ConsumptionRecordClient(proxyAddress, wallet, provider);

  try {
    console.log('=== Single Record Submission Example ===');
    
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

    // Submit the consumption record with owner
    await consumptionRecord.submit(crHash, recordOwner, metadata);

    // Verify the record exists
    const exists = await consumptionRecord.isExists(crHash);
    console.log('Record exists:', exists);

    // Get complete record data
    const record = await consumptionRecord.getRecord(crHash);
    console.log('Complete record:', {
      submittedBy: record.submittedBy,
      submittedAt: new Date(Number(record.submittedAt) * 1000),
      owner: record.owner,
      metadataCount: record.metadataKeys.length
    });

    // Get metadata as key-value object
    const retrievedMetadata = consumptionRecord.getMetadataFromRecord(record);
    console.log('Retrieved metadata:', retrievedMetadata);

    // Get specific metadata value
    const source = consumptionRecord.getMetadataValue(record, 'source');
    const amount = consumptionRecord.getMetadataValue(record, 'amount');
    console.log(`Energy source: ${source}, Amount: ${amount}`);

    console.log('\n=== Batch Submission Example ===');
    
    // Prepare batch submission data
    const batchRequests: BatchSubmissionRequest[] = [];
    
    for (let i = 0; i < 5; i++) {
      const batchData = {
        deviceId: `smart-meter-${i + 2}`,
        timestamp: Date.now() + i * 1000,
        amount: 100 + i * 25,
        source: i % 2 === 0 ? 'solar' : 'wind'
      };
      
      const batchHash = ConsumptionRecordClient.generateHash(batchData);
      const batchMetadata = new ConsumptionMetadataBuilder()
        .setSource(batchData.source)
        .setAmount(batchData.amount.toString())
        .setUnit('kWh')
        .setTimestamp(batchData.timestamp)
        .setCustom('device_id', batchData.deviceId)
        .build();
      
      batchRequests.push({
        crHash: batchHash,
        owner: recordOwner,
        metadata: batchMetadata
      });
    }

    console.log(`Submitting batch of ${batchRequests.length} records...`);
    
    // Submit batch
    const batchResult = await consumptionRecord.submitBatch(batchRequests);
    console.log('Batch submission result:', batchResult);

    console.log('\n=== Owner Query Example ===');
    
    // Get all records owned by the address
    const ownerRecordHashes = await consumptionRecord.getRecordsByOwner(recordOwner);
    console.log(`Owner has ${ownerRecordHashes.length} consumption records`);

    // Get complete records for the owner
    const ownerRecords = await consumptionRecord.getCompleteRecordsByOwner(recordOwner);
    console.log('Owner records summary:');
    ownerRecords.forEach((record, index) => {
      const metadata = consumptionRecord.getMetadataFromRecord(record);
      console.log(`  ${index + 1}. Device: ${metadata.device_id}, Amount: ${metadata.amount} ${metadata.unit}`);
    });

    console.log('\n=== Event Listening Example ===');
    
    // Listen for events
    consumptionRecord.onSubmitted((crHash, cra, timestamp) => {
      console.log(`🔔 New consumption record: ${crHash} by ${cra} at ${new Date(Number(timestamp) * 1000)}`);
    });

    consumptionRecord.onBatchSubmitted((batchSize, cra, timestamp) => {
      console.log(`🔔 Batch submitted: ${batchSize} records by ${cra} at ${new Date(Number(timestamp) * 1000)}`);
    });

    console.log('\n=== Contract Information ===');
    
    // Get contract information
    const version = await consumptionRecord.getVersion();
    const maxBatchSize = await consumptionRecord.contract.MAX_BATCH_SIZE();
    const craRegistry = await consumptionRecord.getCraRegistry();
    const owner = await consumptionRecord.getOwner();
    
    console.log(`Contract version: ${version}`);
    console.log(`Maximum batch size: ${maxBatchSize}`);
    console.log(`CRA Registry: ${craRegistry}`);
    console.log(`Contract owner: ${owner}`);

    console.log('\n=== Upgrade Example (Owner Only) ===');
    
    // Note: This would only work if the wallet is the contract owner
    // const newImplementationAddress = '0x...new-implementation-address';
    // await consumptionRecord.upgradeTo(newImplementationAddress);
    console.log('Upgrade functions available for contract owner:');
    console.log('- upgradeTo(newImplementation): Upgrade to new implementation');
    console.log('- upgradeToAndCall(newImplementation, data): Upgrade and call function');
    console.log('- Address used should be PROXY address, not implementation!');

  } catch (error) {
    console.error('Error:', error);
  }
}

// Batch submission helper example
export async function submitLargeDataset(
  client: ConsumptionRecordClient,
  data: Array<{hash: string, owner: string, metadata: ConsumptionMetadata}>
) {
  const BATCH_SIZE = 50; // Use smaller batches for large datasets
  const batches: BatchSubmissionRequest[][] = [];
  
  // Split data into batches
  for (let i = 0; i < data.length; i += BATCH_SIZE) {
    const batch = data.slice(i, i + BATCH_SIZE).map(item => ({
      crHash: item.hash,
      owner: item.owner,
      metadata: item.metadata
    }));
    batches.push(batch);
  }
  
  console.log(`Submitting ${data.length} records in ${batches.length} batches...`);
  
  const results: BatchSubmissionResult[] = [];
  
  for (let i = 0; i < batches.length; i++) {
    console.log(`Processing batch ${i + 1}/${batches.length}...`);
    try {
      const result = await client.submitBatch(batches[i]);
      results.push(result);
      console.log(`✅ Batch ${i + 1} completed: ${result.batchSize} records`);
    } catch (error) {
      console.error(`❌ Batch ${i + 1} failed:`, error);
      // Decide whether to continue or abort
      break;
    }
  }
  
  const totalSubmitted = results.reduce((sum, result) => sum + result.batchSize, 0);
  console.log(`🎉 Total records submitted: ${totalSubmitted}/${data.length}`);
  
  return results;
}

/**
 * Advanced usage examples and utilities
 */

// Example: Batch processing with retry logic
export class BatchConsumptionProcessor {
  private client: ConsumptionRecordClient;
  private maxRetries: number = 3;
  private batchSize: number = 50;

  constructor(client: ConsumptionRecordClient) {
    this.client = client;
  }

  public async processBatch(records: Array<{
    hash: string;
    owner: string;
    metadata: ConsumptionMetadata;
  }>, retryFailures: boolean = true): Promise<{
    successful: string[];
    failed: Array<{ hash: string; error: string }>;
  }> {
    const successful: string[] = [];
    const failed: Array<{ hash: string; error: string }> = [];
    
    // Process in chunks to avoid gas limit issues
    for (let i = 0; i < records.length; i += this.batchSize) {
      const chunk = records.slice(i, i + this.batchSize);
      console.log(`📦 Processing batch ${Math.floor(i / this.batchSize) + 1}/${Math.ceil(records.length / this.batchSize)}`);

      const batchRequests: BatchSubmissionRequest[] = chunk.map(r => ({
        crHash: r.hash,
        owner: r.owner,
        metadata: r.metadata
      }));

      try {
        await this.client.submitBatch(batchRequests);
        successful.push(...chunk.map(r => r.hash));
        console.log(`✅ Successfully processed ${chunk.length} records`);
      } catch (error) {
        console.warn(`⚠️ Batch failed, falling back to individual submissions`);
        
        // Fallback to individual submissions
        for (const record of chunk) {
          try {
            await this.client.submit(record.hash, record.owner, record.metadata);
            successful.push(record.hash);
          } catch (individualError) {
            failed.push({
              hash: record.hash,
              error: individualError instanceof Error ? individualError.message : String(individualError)
            });
          }
        }
      }
    }

    // Retry failed records if requested
    if (retryFailures && failed.length > 0) {
      console.log(`🔄 Retrying ${failed.length} failed records...`);
      const retryResults = await this.retryFailed(records.filter(r => 
        failed.some(f => f.hash === r.hash)
      ));
      
      // Update results with retry outcomes
      for (const hash of retryResults.successful) {
        const index = failed.findIndex(f => f.hash === hash);
        if (index !== -1) {
          failed.splice(index, 1);
          successful.push(hash);
        }
      }
    }

    return { successful, failed };
  }

  private async retryFailed(records: Array<{
    hash: string;
    owner: string;
    metadata: ConsumptionMetadata;
  }>): Promise<{ successful: string[]; failed: string[] }> {
    const successful: string[] = [];
    const stillFailed: string[] = [];

    for (const record of records) {
      let attempt = 0;
      let success = false;

      while (attempt < this.maxRetries && !success) {
        try {
          await new Promise(resolve => setTimeout(resolve, 1000 * attempt)); // Exponential backoff
          await this.client.submit(record.hash, record.owner, record.metadata);
          successful.push(record.hash);
          success = true;
        } catch (error) {
          attempt++;
          if (attempt >= this.maxRetries) {
            stillFailed.push(record.hash);
            console.error(`❌ Failed to retry ${record.hash} after ${this.maxRetries} attempts`);
          }
        }
      }
    }

    return { successful, failed: stillFailed };
  }
}

// Example: Consumption record analytics
export class ConsumptionAnalytics {
  private client: ConsumptionRecordClient;

  constructor(client: ConsumptionRecordClient) {
    this.client = client;
  }

  public async analyzeOwnerConsumption(ownerAddress: string): Promise<{
    totalRecords: number;
    energySources: Map<string, number>;
    totalAmount: number;
    averageAmount: number;
    timeRange: { earliest: Date; latest: Date };
    recordsByMonth: Map<string, number>;
  }> {
    console.log(`📊 Analyzing consumption for owner: ${ownerAddress}`);

    const recordHashes = await this.client.getRecordsByOwner(ownerAddress);
    const records: CRRecord[] = [];
    
    // Fetch all records
    for (const hash of recordHashes) {
      const record = await this.client.getRecord(hash);
      if (record) {
        records.push(record);
      }
    }

    if (records.length === 0) {
      return {
        totalRecords: 0,
        energySources: new Map(),
        totalAmount: 0,
        averageAmount: 0,
        timeRange: { earliest: new Date(), latest: new Date() },
        recordsByMonth: new Map()
      };
    }

    // Analyze data
    const energySources = new Map<string, number>();
    const recordsByMonth = new Map<string, number>();
    let totalAmount = 0;
    const timestamps = records.map(r => new Date(Number(r.submittedAt) * 1000));

    for (const record of records) {
      // Analyze metadata
      const metadata = this.parseMetadata(record.metadataKeys, record.metadataValues);
      
      // Count energy sources
      const source = metadata.source || 'unknown';
      energySources.set(source, (energySources.get(source) || 0) + 1);
      
      // Sum amounts if available
      const amount = parseFloat(metadata.amount || '0');
      if (!isNaN(amount)) {
        totalAmount += amount;
      }

      // Group by month
      const date = new Date(Number(record.submittedAt) * 1000);
      const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
      recordsByMonth.set(monthKey, (recordsByMonth.get(monthKey) || 0) + 1);
    }

    return {
      totalRecords: records.length,
      energySources,
      totalAmount,
      averageAmount: totalAmount / records.length,
      timeRange: {
        earliest: new Date(Math.min(...timestamps.map(d => d.getTime()))),
        latest: new Date(Math.max(...timestamps.map(d => d.getTime())))
      },
      recordsByMonth
    };
  }

  private parseMetadata(keys: string[], values: string[]): { [key: string]: string } {
    const metadata: { [key: string]: string } = {};
    for (let i = 0; i < keys.length; i++) {
      metadata[keys[i]] = values[i];
    }
    return metadata;
  }

  public async generateReport(ownerAddress: string): Promise<string> {
    const analysis = await this.analyzeOwnerConsumption(ownerAddress);
    
    let report = `# Consumption Report for ${ownerAddress}\n\n`;
    report += `**Total Records:** ${analysis.totalRecords}\n`;
    report += `**Total Amount:** ${analysis.totalAmount.toFixed(2)} units\n`;
    report += `**Average Amount:** ${analysis.averageAmount.toFixed(2)} units per record\n`;
    report += `**Time Range:** ${analysis.timeRange.earliest.toDateString()} - ${analysis.timeRange.latest.toDateString()}\n\n`;
    
    report += `## Energy Sources\n`;
    for (const [source, count] of analysis.energySources.entries()) {
      const percentage = ((count / analysis.totalRecords) * 100).toFixed(1);
      report += `- **${source}:** ${count} records (${percentage}%)\n`;
    }
    
    report += `\n## Monthly Distribution\n`;
    for (const [month, count] of analysis.recordsByMonth.entries()) {
      report += `- **${month}:** ${count} records\n`;
    }
    
    return report;
  }
}

// Example: Real-time consumption monitoring
export class ConsumptionMonitor {
  private client: ConsumptionRecordClient;
  private isMonitoring: boolean = false;
  private eventHandlers: Map<string, Function[]> = new Map();

  constructor(client: ConsumptionRecordClient) {
    this.client = client;
  }

  public startMonitoring(ownerAddresses?: string[]) {
    if (this.isMonitoring) {
      console.warn('⚠️ Monitoring already active');
      return;
    }

    console.log('👀 Starting consumption record monitoring...');
    this.isMonitoring = true;

    this.client.onSubmitted((hash, cra, timestamp) => {
      this.handleNewRecord(hash, cra, timestamp, ownerAddresses);
    });

    this.client.onBatchSubmitted((batchSize, cra, timestamp) => {
      this.emit('batchProcessed', { batchSize, cra, timestamp });
      console.log(`📦 Batch of ${batchSize} records processed by ${cra}`);
    });
  }

  public stopMonitoring() {
    this.client.removeAllListeners();
    this.isMonitoring = false;
    console.log('⏹️ Monitoring stopped');
  }

  private async handleNewRecord(hash: string, cra: string, timestamp: bigint, watchAddresses?: string[]) {
    try {
      const record = await this.client.getRecord(hash);
      if (!record) return;

      // Filter by watched addresses if specified
      if (watchAddresses && !watchAddresses.includes(record.owner)) {
        return;
      }

      const metadata = this.parseMetadata(record.metadataKeys, record.metadataValues);
      
      this.emit('newRecord', {
        hash,
        cra,
        timestamp,
        owner: record.owner,
        metadata
      });

      console.log(`🆕 New consumption record: ${hash}`);
      console.log(`   Owner: ${record.owner}`);
      console.log(`   CRA: ${cra}`);
      console.log(`   Amount: ${metadata.amount || 'N/A'} ${metadata.unit || ''}`);
      console.log(`   Source: ${metadata.source || 'N/A'}`);

    } catch (error) {
      console.error(`❌ Error processing new record ${hash}:`, error);
    }
  }

  private parseMetadata(keys: string[], values: string[]): { [key: string]: string } {
    const metadata: { [key: string]: string } = {};
    for (let i = 0; i < keys.length; i++) {
      metadata[keys[i]] = values[i];
    }
    return metadata;
  }

  public on(event: string, handler: Function) {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, []);
    }
    this.eventHandlers.get(event)!.push(handler);
  }

  private emit(event: string, data: any) {
    const handlers = this.eventHandlers.get(event) || [];
    handlers.forEach(handler => {
      try {
        handler(data);
      } catch (error) {
        console.error(`❌ Event handler error for ${event}:`, error);
      }
    });
  }
}
