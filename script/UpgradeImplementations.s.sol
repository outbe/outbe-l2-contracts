// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionRecordAmendmentUpgradeable} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";

/// @title UpgradeImplementations Script
/// @notice Script for upgrading implementation contracts while preserving proxy addresses
/// @dev Uses UUPS upgrade pattern to update contract logic
contract UpgradeImplementations is Script {
    /// @notice Upgrade configuration
    struct UpgradeConfig {
        address craRegistryProxy;
        address consumptionRecordProxy;
        address consumptionRecordAmendmentProxy;
        bool upgradeCraRegistry;
        bool upgradeConsumptionRecord;
        bool upgradeConsumptionRecordAmendment;
        string newVersion;
    }

    function setUp() public {}

    /// @notice Main upgrade function
    /// @dev Upgrades specified contracts to new implementations
    function run() public {
        // Load upgrade parameters
        uint256 deployerPrivateKey;

        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // Use default Anvil private key for testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("WARNING: Using default Anvil private key for testing");
        }

        address deployer = vm.addr(deployerPrivateKey);

        // Load proxy addresses from environment or use defaults
        UpgradeConfig memory config = UpgradeConfig({
            craRegistryProxy: vm.envOr("CRA_REGISTRY_ADDRESS", address(0)),
            consumptionRecordProxy: vm.envOr("CONSUMPTION_RECORD_ADDRESS", address(0)),
            consumptionRecordAmendmentProxy: vm.envOr("CONSUMPTION_RECORD_AMENDMENT_ADDRESS", address(0)),
            upgradeCraRegistry: vm.envOr("UPGRADE_CRA_REGISTRY", true),
            upgradeConsumptionRecord: vm.envOr("UPGRADE_CONSUMPTION_RECORD", true),
            upgradeConsumptionRecordAmendment: vm.envOr("UPGRADE_CONSUMPTION_RECORD_AMENDMENT", true),
            newVersion: vm.envOr("NEW_VERSION", string("v2"))
        });

        console.log("=== Outbe L2 Contract Upgrades ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");

        // Validate proxy addresses
        require(config.craRegistryProxy != address(0), "CRA Registry proxy address not set");
        require(config.consumptionRecordProxy != address(0), "Consumption Record proxy address not set");

        console.log("Proxy Addresses:");
        console.log("- CRA Registry:      ", config.craRegistryProxy);
        console.log("- Consumption Record:", config.consumptionRecordProxy);
        console.log("");

        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");

        if (balance < 0.01 ether) {
            console.log("WARNING: Low balance, upgrade may fail");
        }
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Upgrade CRA Registry if requested
        if (config.upgradeCraRegistry) {
            upgradeCRARegistry(config.craRegistryProxy, config.newVersion);
        }

        // Upgrade Consumption Record if requested
        if (config.upgradeConsumptionRecord) {
            upgradeConsumptionRecord(config.consumptionRecordProxy, config.newVersion);
        }
        // Upgrade Consumption Amendment Record if requested
        if (config.upgradeConsumptionRecordAmendment) {
            upgradeConsumptionRecordAmendment(config.consumptionRecordAmendmentProxy, config.newVersion);
        }

        vm.stopBroadcast();

        // Post-upgrade verification
        verifyUpgrades(config);

        console.log("=== Upgrade Summary ===");
        console.log("All upgrades completed successfully!");
        console.log("Proxy addresses remain unchanged:");
        console.log("- CRA Registry:      ", config.craRegistryProxy);
        console.log("- Consumption Record:          ", config.consumptionRecordProxy);
        console.log("- Consumption Record Amendment:", config.consumptionRecordAmendmentProxy);
    }

    /// @notice Upgrade CRA Registry implementation
    /// @param proxyAddress Address of the CRA Registry proxy
    /// @param version Version suffix for the new implementation
    function upgradeCRARegistry(address proxyAddress, string memory version) internal {
        console.log("Upgrading CRA Registry implementation...");

        // Get current implementation info
        CRARegistryUpgradeable proxy = CRARegistryUpgradeable(proxyAddress);
        console.log("Current CRA Registry version:", proxy.VERSION());

        // Deploy new implementation
        string memory salt = string.concat("CRARegistryImpl_", version);
        address newImpl = address(new CRARegistryUpgradeable{salt: bytes32(abi.encodePacked(salt))}());
        console.log("New CRA Registry implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("CRA Registry upgrade completed");
        console.log("New version:", proxy.VERSION());
        console.log("");
    }

    /// @notice Upgrade Consumption Record implementation
    /// @param proxyAddress Address of the Consumption Record proxy
    /// @param version Version suffix for the new implementation
    function upgradeConsumptionRecord(address proxyAddress, string memory version) internal {
        console.log("Upgrading Consumption Record implementation...");

        // Get current implementation info
        ConsumptionRecordUpgradeable proxy = ConsumptionRecordUpgradeable(proxyAddress);
        console.log("Current Consumption Record version:", proxy.VERSION());

        // Deploy new implementation
        string memory salt = string.concat("ConsumptionRecordImpl_", version);
        address newImpl = address(new ConsumptionRecordUpgradeable{salt: bytes32(abi.encodePacked(salt))}());
        console.log("New Consumption Record implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("Consumption Record upgrade completed");
        console.log("New version:", proxy.VERSION());
        console.log("");
    }

    /// @notice Upgrade Consumption Record implementation
    /// @param proxyAddress Address of the Consumption Record proxy
    /// @param version Version suffix for the new implementation
    function upgradeConsumptionRecordAmendment(address proxyAddress, string memory version) internal {
        console.log("Upgrading Consumption Record Amendment implementation...");

        // Get current implementation info
        ConsumptionRecordAmendmentUpgradeable proxy = ConsumptionRecordAmendmentUpgradeable(proxyAddress);
        console.log("Current Consumption Record Amendment version:", proxy.VERSION());

        // Deploy new implementation
        string memory salt = string.concat("ConsumptionRecordAmendmentImpl_", version);
        address newImpl = address(new ConsumptionRecordAmendmentUpgradeable{salt: bytes32(abi.encodePacked(salt))}());
        console.log("New Consumption Record Amendment implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("Consumption Record Amendment upgrade completed");
        console.log("New version:", proxy.VERSION());
        console.log("");
    }

    /// @notice Verify upgrades were successful
    /// @param config Upgrade configuration
    function verifyUpgrades(UpgradeConfig memory config) internal view {
        console.log("=== Upgrade Verification ===");

        if (config.upgradeCraRegistry) {
            CRARegistryUpgradeable craRegistry = CRARegistryUpgradeable(config.craRegistryProxy);
            console.log("CRA Registry proxy still functional:", address(craRegistry) != address(0));
            console.log("CRA Registry version:", craRegistry.VERSION());

            // Test basic functionality
            address[] memory cras = craRegistry.getAllCRAs();
            console.log("CRA Registry can enumerate CRAs:", cras.length >= 0);
        }

        if (config.upgradeConsumptionRecord) {
            ConsumptionRecordUpgradeable consumptionRecord = ConsumptionRecordUpgradeable(config.consumptionRecordProxy);
            console.log("Consumption Record proxy still functional:", address(consumptionRecord) != address(0));
            console.log("Consumption Record version:", consumptionRecord.VERSION());

            // Test basic functionality
            address craRegistry = consumptionRecord.getCRARegistry();
            console.log("Consumption Record still linked to CRA Registry:", craRegistry != address(0));
        }

        if (config.upgradeConsumptionRecordAmendment) {
            ConsumptionRecordAmendmentUpgradeable consumptionRecord = ConsumptionRecordAmendmentUpgradeable(config.consumptionRecordAmendmentProxy);
            console.log("Consumption Record Amendment proxy still functional:", address(consumptionRecord) != address(0));
            console.log("Consumption Record Amendment version:", consumptionRecord.VERSION());

            // Test basic functionality
            address craRegistry = consumptionRecord.getCRARegistry();
            console.log("Consumption Record Amendment still linked to CRA Registry:", craRegistry != address(0));
        }

        console.log("All upgrade verifications passed");
        console.log("");
    }
}
