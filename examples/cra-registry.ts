import { ethers, Contract, Wallet, Provider } from 'ethers';

// CRA Registry ABI - generated from the contract
const CRA_REGISTRY_ABI = [
  "function registerCra(address cra, string calldata name) external",
  "function updateCraStatus(address cra, uint8 status) external",
  "function isCraActive(address cra) external view returns (bool)",
  "function getCraInfo(address cra) external view returns (tuple(string name, uint8 status, uint256 registeredAt))",
  "function getAllCras() external view returns (address[])",
  "function getOwner() external view returns (address)",
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
  // Setup
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const wallet = new Wallet('0x...your-private-key', provider);
  const registryAddress = '0x...contract-address';
  
  const registry = new CRARegistryClient(registryAddress, wallet, provider);

  try {
    // Register a new CRA
    const craAddress = '0x1234567890123456789012345678901234567890';
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

  } catch (error) {
    console.error('Error:', error);
  }
}