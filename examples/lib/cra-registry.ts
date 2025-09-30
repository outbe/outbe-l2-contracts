import { ethers, Contract, Wallet, Provider } from 'ethers';

// CRARegistryUpgradeable ABI - generated from the upgradeable contract
const CRA_REGISTRY_ABI = [
  // Initialization (only called once during deployment)
  "function initialize(address _owner) external",
  
  // Core functions
  "function registerCra(address cra, string calldata name) external",
  "function updateCraStatus(address cra, uint8 status) external",
  "function isCraActive(address cra) external view returns (bool)",
  "function getCraInfo(address cra) external view returns (tuple(string name, uint8 status, uint256 registeredAt))",
  "function getAllCras() external view returns (address[])",
  "function getOwner() external view returns (address)",
  
  // Upgrade functions (owner only)
  "function upgradeTo(address newImplementation) external",
  "function upgradeToAndCall(address newImplementation, bytes calldata data) external payable",
  "function VERSION() external pure returns (string)",
  
  // Events
  "event CRARegistered(address indexed cra, string name, uint256 timestamp)",
  "event CRAStatusUpdated(address indexed cra, uint8 oldStatus, uint8 newStatus, uint256 timestamp)"
];

// CRA Status enum values
export enum CRAStatus {
  Inactive = 0,
  Active = 1,
  Suspended = 2
}

export interface CRAInfo {
  name: string;
  status: CRAStatus;
  registeredAt: bigint;
}

export class CRARegistryClient {
  private contract: Contract;
  private signer: Wallet;

  constructor(
    contractAddress: string,
    signer: Wallet,
    provider: Provider
  ) {
    this.signer = signer.connect(provider);
    this.contract = new Contract(contractAddress, CRA_REGISTRY_ABI, this.signer);
  }

  /**
   * Register a new CRA (owner only)
   */
  async registerCra(craAddress: string, name: string): Promise<void> {
    try {
      const tx = await this.contract.registerCra(craAddress, name);
      await tx.wait();
      console.log(`✅ CRA registered: ${craAddress} with name "${name}"`);
    } catch (error: any) {
      if (error.message.includes('CRAAlreadyRegistered')) {
        throw new Error(`CRA ${craAddress} is already registered`);
      } else if (error.message.includes('EmptyCRAName')) {
        throw new Error('CRA name cannot be empty');
      } else if (error.message.includes('UnauthorizedAccess')) {
        throw new Error('Only owner can register CRAs');
      }
      throw error;
    }
  }

  /**
   * Update CRA status (owner only)
   */
  async updateCraStatus(craAddress: string, status: CRAStatus): Promise<void> {
    try {
      const tx = await this.contract.updateCraStatus(craAddress, status);
      await tx.wait();
      console.log(`✅ CRA status updated: ${craAddress} -> ${CRAStatus[status]}`);
    } catch (error: any) {
      if (error.message.includes('CRANotFound')) {
        throw new Error(`CRA ${craAddress} not found`);
      } else if (error.message.includes('UnauthorizedAccess')) {
        throw new Error('Only owner can update CRA status');
      }
      throw error;
    }
  }

  /**
   * Check if CRA is active
   */
  async isCraActive(craAddress: string): Promise<boolean> {
    return await this.contract.isCraActive(craAddress);
  }

  /**
   * Get CRA information
   */
  async getCraInfo(craAddress: string): Promise<CRAInfo> {
    try {
      const result = await this.contract.getCraInfo(craAddress);
      return {
        name: result.name,
        status: result.status,
        registeredAt: result.registeredAt
      };
    } catch (error: any) {
      if (error.message.includes('CRANotFound')) {
        throw new Error(`CRA ${craAddress} not found`);
      }
      throw error;
    }
  }

  /**
   * Get all registered CRA addresses
   */
  async getAllCras(): Promise<string[]> {
    return await this.contract.getAllCras();
  }

  /**
   * Get total number of registered CRAs
   */
  async getCraCount(): Promise<number> {
    const addresses = await this.getAllCras();
    return addresses.length;
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
   * Listen for CRA registration events
   */
  onCRARegistered(callback: (cra: string, name: string, timestamp: bigint) => void): void {
    this.contract.on('CRARegistered', callback);
  }

  /**
   * Listen for CRA status update events
   */
  onCRAStatusUpdated(
    callback: (cra: string, oldStatus: CRAStatus, newStatus: CRAStatus, timestamp: bigint) => void
  ): void {
    this.contract.on('CRAStatusUpdated', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }
}

// Example usage
export async function exampleUsage() {
  // Setup - IMPORTANT: Use proxy address, not implementation address!
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const wallet = new Wallet('0x...your-private-key', provider);
  const proxyAddress = '0x...proxy-contract-address'; // Always use proxy address
  
  const registry = new CRARegistryClient(proxyAddress, wallet, provider);

  try {
    // Register a new CRA
    const craAddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
    await registry.registerCra(craAddress, 'Green Energy CRA');

    // Check if CRA is active
    const isActive = await registry.isCraActive(craAddress);
    console.log(`CRA is active: ${isActive}`);

    // Get CRA information
    const craInfo = await registry.getCraInfo(craAddress);
    console.log('CRA Info:', {
      name: craInfo.name,
      status: CRAStatus[craInfo.status],
      registeredAt: new Date(Number(craInfo.registeredAt) * 1000)
    });

    // Get all CRAs
    const allCRAs = await registry.getAllCras();
    console.log('All CRAs:', allCRAs);

    // Update CRA status
    await registry.updateCraStatus(craAddress, CRAStatus.Suspended);

    // Verify status change
    const updatedInfo = await registry.getCraInfo(craAddress);
    console.log('Updated status:', CRAStatus[updatedInfo.status]);

    // Listen for events
    registry.onCRARegistered((cra, name, timestamp) => {
      console.log(`🔔 New CRA registered: ${name} at ${cra}`);
    });

    registry.onCRAStatusUpdated((cra, oldStatus, newStatus, timestamp) => {
      console.log(`🔔 CRA status changed: ${cra} from ${CRAStatus[oldStatus]} to ${CRAStatus[newStatus]}`);
    });

    // Get contract information
    console.log('\n=== Contract Information ===');
    const version = await registry.getVersion();
    const owner = await registry.getOwner();
    const craCount = await registry.getCraCount();
    
    console.log(`Contract version: ${version}`);
    console.log(`Contract owner: ${owner}`);
    console.log(`Total CRAs: ${craCount}`);

    console.log('\n=== Upgrade Example (Owner Only) ===');
    
    // Note: This would only work if the wallet is the contract owner
    // const newImplementationAddress = '0x...new-implementation-address';
    // await registry.upgradeTo(newImplementationAddress);
    console.log('Upgrade functions available for contract owner:');
    console.log('- upgradeTo(newImplementation): Upgrade to new implementation');
    console.log('- upgradeToAndCall(newImplementation, data): Upgrade and call function');
    console.log('- Address used should be PROXY address, not implementation!');

  } catch (error) {
    console.error('Error:', error);
  }
}

/**
 * Advanced usage examples
 */

// Example: Multi-step CRA management workflow
export async function advancedCRAManagement() {
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const ownerWallet = new Wallet('0x...', provider);
  const registryAddress = '0x...';
  
  const registry = new CRARegistryClient(registryAddress, ownerWallet, provider);

  try {
    // 1. Register multiple CRAs in batch
    const craAddresses = ['0xCRA1...', '0xCRA2...', '0xCRA3...'];
    const craNames = ['Solar CRA', 'Wind CRA', 'Hydro CRA'];
    
    console.log('🔄 Registering multiple CRAs...');
    for (let i = 0; i < craAddresses.length; i++) {
      await registry.registerCra(craAddresses[i], craNames[i]);
      console.log(`✅ Registered: ${craNames[i]}`);
    }

    // 2. Monitor CRA status changes
    console.log('👂 Setting up event listeners...');
    registry.onCRAStatusUpdated((cra, oldStatus, newStatus, timestamp) => {
      console.log(`📢 CRA ${cra} status: ${CRAStatus[oldStatus]} → ${CRAStatus[newStatus]} at ${new Date(Number(timestamp) * 1000)}`);
    });

    // 3. Get comprehensive CRA overview
    console.log('📊 Generating CRA overview...');
    const allCras = await registry.getAllCras();
    const craOverview = [];
    
    for (const craAddr of allCras) {
      const info = await registry.getCraInfo(craAddr);
      const isActive = await registry.isCraActive(craAddr);
      
      craOverview.push({
        address: craAddr,
        name: info.name,
        status: CRAStatus[info.status],
        isActive,
        registeredAt: new Date(Number(info.registeredAt) * 1000)
      });
    }

    console.table(craOverview);

    // 4. Bulk status management
    console.log('🔧 Managing CRA statuses...');
    let activeCount = 0;
    let suspendedCount = 0;
    
    for (const craAddr of allCras) {
      const isActive = await registry.isCraActive(craAddr);
      if (isActive) {
        activeCount++;
      } else {
        // Example: Reactivate suspended CRAs after maintenance
        await registry.updateCraStatus(craAddr, CRAStatus.Active);
        suspendedCount++;
      }
    }

    console.log(`📈 Status Summary: ${activeCount} active, ${suspendedCount} reactivated`);

  } catch (error) {
    console.error('❌ CRA management workflow failed:', error);
  }
}

// Example: Event-driven CRA monitoring service
export class CRAMonitoringService {
  private registry: CRARegistryClient;
  private eventHandlers: Map<string, Function[]> = new Map();
  private isMonitoring: boolean = false;

  constructor(registryAddress: string, provider: Provider) {
    // Use read-only provider for monitoring
    const readOnlyWallet = Wallet.createRandom().connect(provider) as unknown as Wallet;
    this.registry = new CRARegistryClient(registryAddress, readOnlyWallet, provider);
  }

  public startMonitoring() {
    if (this.isMonitoring) {
      console.warn('⚠️ Monitoring already started');
      return;
    }

    this.setupEventListeners();
    this.isMonitoring = true;
    console.log('👀 CRA monitoring service started');
  }

  public stopMonitoring() {
    this.registry.removeAllListeners();
    this.isMonitoring = false;
    console.log('⏹️ CRA monitoring service stopped');
  }

  private setupEventListeners() {
    // Monitor new CRA registrations
    this.registry.onCRARegistered((cra, name, timestamp) => {
      const data = { cra, name, timestamp, type: 'registration' };
      this.emit('craRegistered', data);
      console.log(`🆕 New CRA registered: ${name} (${cra})`);
    });

    // Monitor status changes
    this.registry.onCRAStatusUpdated((cra, oldStatus, newStatus, timestamp) => {
      const data = { cra, oldStatus, newStatus, timestamp, type: 'statusUpdate' };
      this.emit('craStatusChanged', data);
      console.log(`🔄 CRA ${cra}: ${CRAStatus[oldStatus]} → ${CRAStatus[newStatus]}`);
    });
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

  public async getSystemStatus() {
    console.log('📊 Generating system status...');
    
    const allCras = await this.registry.getAllCras();
    const statusCounts = new Map<string, number>();
    const craDetails = [];
    
    for (const craAddr of allCras) {
      const info = await this.registry.getCraInfo(craAddr);
      const statusName = CRAStatus[info.status];
      const currentCount = statusCounts.get(statusName) || 0;
      statusCounts.set(statusName, currentCount + 1);
      
      craDetails.push({
        address: craAddr,
        name: info.name,
        status: statusName,
        registeredAt: new Date(Number(info.registeredAt) * 1000)
      });
    }

    return {
      totalCras: allCras.length,
      statusBreakdown: Object.fromEntries(statusCounts),
      craDetails,
      isMonitoring: this.isMonitoring,
      lastUpdated: new Date()
    };
  }

  public async getActiveCount(): Promise<number> {
    const allCras = await this.registry.getAllCras();
    let activeCount = 0;
    
    for (const craAddr of allCras) {
      if (await this.registry.isCraActive(craAddr)) {
        activeCount++;
      }
    }
    
    return activeCount;
  }
}

// Example: CRA health checker
export class CRAHealthChecker {
  private registry: CRARegistryClient;
  
  constructor(registryAddress: string, provider: Provider) {
    const readOnlyWallet = Wallet.createRandom().connect(provider) as unknown as Wallet;
    this.registry = new CRARegistryClient(registryAddress, readOnlyWallet, provider);
  }

  public async checkCRAHealth(craAddress: string): Promise<{
    isHealthy: boolean;
    issues: string[];
    info: any;
  }> {
    const issues: string[] = [];
    
    try {
      // Check if CRA exists
      const info = await this.registry.getCraInfo(craAddress);
      if (!info.name) {
        issues.push('CRA not found in registry');
        return { isHealthy: false, issues, info: null };
      }

      // Check if CRA is active
      const isActive = await this.registry.isCraActive(craAddress);
      if (!isActive) {
        issues.push(`CRA status is ${CRAStatus[info.status]}, not Active`);
      }

      // Check registration age
      const registeredAt = new Date(Number(info.registeredAt) * 1000);
      const daysSinceRegistration = (Date.now() - registeredAt.getTime()) / (1000 * 60 * 60 * 24);
      
      if (daysSinceRegistration < 1) {
        issues.push('CRA registered less than 24 hours ago (may need time to stabilize)');
      }

      return {
        isHealthy: issues.length === 0,
        issues,
        info: {
          name: info.name,
          status: CRAStatus[info.status],
          isActive,
          registeredAt,
          daysSinceRegistration: Math.floor(daysSinceRegistration)
        }
      };

    } catch (error) {
      issues.push(`Failed to check CRA health: ${error}`);
      return { isHealthy: false, issues, info: null };
    }
  }

  public async checkAllCRAHealth(): Promise<{
    totalCras: number;
    healthyCras: number;
    issues: { [address: string]: string[] };
  }> {
    const allCras = await this.registry.getAllCras();
    const issues: { [address: string]: string[] } = {};
    let healthyCras = 0;

    for (const craAddr of allCras) {
      const health = await this.checkCRAHealth(craAddr);
      if (health.isHealthy) {
        healthyCras++;
      } else {
        issues[craAddr] = health.issues;
      }
    }

    return {
      totalCras: allCras.length,
      healthyCras,
      issues
    };
  }
}