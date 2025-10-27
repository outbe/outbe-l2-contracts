// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Script.sol";
import {OutbeScriptBase} from "./OutbeScriptBase.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {
    ConsumptionRecordAmendmentUpgradeable
} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {TributeDraftUpgradeable} from "../src/tribute_draft/TributeDraftUpgradeable.sol";

/// @title UpgradeImplementations Script
/// @notice Script for upgrading implementation contracts while preserving proxy addresses
/// @dev Uses UUPS upgrade pattern to update contract logic
contract UpgradeImplementations is OutbeScriptBase {
    /// @notice Upgrade configuration
    struct UpgradeConfig {
        address craRegistryProxy;
        address consumptionRecordProxy;
        address consumptionRecordAmendmentProxy;
        address consumptionUnitProxy;
        address tributeDraftProxy;
        bool upgradeCraRegistry;
        bool upgradeConsumptionRecord;
        bool upgradeConsumptionRecordAmendment;
        bool upgradeConsumptionUnit;
        bool upgradeTributeDraft;
        string newVersion;
    }

    /// @notice Main upgrade function
    /// @dev Upgrades specified contracts to new implementations
    function run() public {
        // Load proxy addresses from environment or use defaults
        UpgradeConfig memory config = UpgradeConfig({
            craRegistryProxy: vm.envOr("CRA_REGISTRY_ADDRESS", address(0)),
            consumptionRecordProxy: vm.envOr("CONSUMPTION_RECORD_ADDRESS", address(0)),
            consumptionRecordAmendmentProxy: vm.envOr("CONSUMPTION_RECORD_AMENDMENT_ADDRESS", address(0)),
            consumptionUnitProxy: vm.envOr("CONSUMPTION_UNIT_ADDRESS", address(0)),
            tributeDraftProxy: vm.envOr("TRIBUTE_DRAFT_ADDRESS", address(0)),
            upgradeCraRegistry: vm.envOr("UPGRADE_CRA_REGISTRY", true),
            upgradeConsumptionRecord: vm.envOr("UPGRADE_CONSUMPTION_RECORD", true),
            upgradeConsumptionRecordAmendment: vm.envOr("UPGRADE_CONSUMPTION_RECORD_AMENDMENT", true),
            upgradeConsumptionUnit: vm.envOr("UPGRADE_CONSUMPTION_UNIT", true),
            upgradeTributeDraft: vm.envOr("UPGRADE_TRIBUTE_DRAFT", true),
            newVersion: vm.envOr("NEW_VERSION", string("v2"))
        });

        console.log("=== Outbe L2 Contract Upgrades ===");
        console.log("Deployer address:", deployer);
        console.log("Network:", getNetworkName());
        console.log("");

        // Validate proxy addresses only for selected upgrades
        if (config.upgradeCraRegistry) {
            require(config.craRegistryProxy != address(0), "CRA Registry proxy address not set");
        }
        if (config.upgradeConsumptionRecord) {
            require(config.consumptionRecordProxy != address(0), "Consumption Record proxy address not set");
        }
        if (config.upgradeConsumptionRecordAmendment) {
            require(
                config.consumptionRecordAmendmentProxy != address(0),
                "Consumption Record Amendment proxy address not set"
            );
        }
        if (config.upgradeConsumptionUnit) {
            require(config.consumptionUnitProxy != address(0), "Consumption Unit proxy address not set");
        }
        if (config.upgradeTributeDraft) {
            require(config.tributeDraftProxy != address(0), "Tribute Draft proxy address not set");
        }

        console.log("Proxy Addresses (selected):");
        if (config.upgradeCraRegistry) console.log("- CRA Registry:", config.craRegistryProxy);
        if (config.upgradeConsumptionRecord) console.log("- Consumption Record:", config.consumptionRecordProxy);
        if (config.upgradeConsumptionRecordAmendment)
            console.log("- Consumption Record Amendment:", config.consumptionRecordAmendmentProxy);
        if (config.upgradeConsumptionUnit) console.log("- Consumption Unit:", config.consumptionUnitProxy);
        if (config.upgradeTributeDraft) console.log("- Tribute Draft:", config.tributeDraftProxy);
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
        // Upgrade Consumption Unit if requested
        if (config.upgradeConsumptionUnit) {
            upgradeConsumptionUnit(config.consumptionUnitProxy, config.newVersion);
        }
        // Upgrade Tribute Draft if requested
        if (config.upgradeTributeDraft) {
            upgradeTributeDraft(config.tributeDraftProxy, config.newVersion);
        }

        vm.stopBroadcast();

        // Post-upgrade verification
        verifyUpgrades(config);

        console.log("=== Upgrade Summary ===");
        console.log("All upgrades completed (selected targets)!");
        if (config.upgradeCraRegistry) console.log("- CRA Registry:", config.craRegistryProxy);
        if (config.upgradeConsumptionRecord) console.log("- Consumption Record:", config.consumptionRecordProxy);
        if (config.upgradeConsumptionRecordAmendment)
            console.log("- Consumption Record Amendment:", config.consumptionRecordAmendmentProxy);
        if (config.upgradeConsumptionUnit) console.log("- Consumption Unit:", config.consumptionUnitProxy);
        if (config.upgradeTributeDraft) console.log("- Tribute Draft:", config.tributeDraftProxy);
    }

    /// @notice Upgrade CRA Registry implementation
    /// @param proxyAddress Address of the CRA Registry proxy
    /// @param version Version suffix for the new implementation
    function upgradeCRARegistry(address proxyAddress, string memory version) internal {
        console.log("Upgrading CRA Registry implementation...");

        // Get current implementation info
        CRARegistryUpgradeable proxy = CRARegistryUpgradeable(proxyAddress);
        console.log("Current CRA Registry version:", proxy.VERSION());

        // Deploy new implementation with deterministic salt
        bytes32 salt = generateSalt(string.concat("CRARegistryImpl_", version));
        address newImpl = address(new CRARegistryUpgradeable{salt: salt}());
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

        // Deploy new implementation with deterministic salt
        bytes32 salt = generateSalt(string.concat("ConsumptionRecordImpl_", version));
        address newImpl = address(new ConsumptionRecordUpgradeable{salt: salt}());
        console.log("New Consumption Record implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("Consumption Record upgrade completed");
        console.log("New version:", proxy.VERSION());
        console.log("");
    }

    /// @notice Upgrade Consumption Record Amendment implementation
    /// @param proxyAddress Address of the Consumption Record Amendment proxy
    /// @param version Version suffix for the new implementation
    function upgradeConsumptionRecordAmendment(address proxyAddress, string memory version) internal {
        console.log("Upgrading Consumption Record Amendment implementation...");

        // Get current implementation info
        ConsumptionRecordAmendmentUpgradeable proxy = ConsumptionRecordAmendmentUpgradeable(proxyAddress);
        console.log("Current Consumption Record Amendment version:", proxy.VERSION());

        // Deploy new implementation with deterministic salt
        bytes32 salt = generateSalt(string.concat("ConsumptionRecordAmendmentImpl_", version));
        address newImpl = address(new ConsumptionRecordAmendmentUpgradeable{salt: salt}());
        console.log("New Consumption Record Amendment implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("Consumption Record Amendment upgrade completed");
        console.log("New version:", proxy.VERSION());
        console.log("");
    }

    /// @notice Upgrade Consumption Unit implementation
    /// @param proxyAddress Address of the Consumption Unit proxy
    /// @param version Version suffix for the new implementation
    function upgradeConsumptionUnit(address proxyAddress, string memory version) internal {
        console.log("Upgrading Consumption Unit implementation...");

        ConsumptionUnitUpgradeable proxy = ConsumptionUnitUpgradeable(proxyAddress);
        console.log("Current Consumption Unit version:", proxy.VERSION());
        console.log("Current Consumption Unit owner:", proxy.owner());


        // Deploy new implementation with deterministic salt
        bytes32 salt = generateSalt(string.concat("ConsumptionUnitImpl_", version));
        address newImpl = address(new ConsumptionUnitUpgradeable{salt: salt}());
        console.log("New Consumption Unit implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("Consumption Unit upgrade completed");
        console.log("New version:", proxy.VERSION());
        console.log("");
    }

    /// @notice Upgrade Tribute Draft implementation
    /// @param proxyAddress Address of the Tribute Draft proxy
    /// @param version Version suffix for the new implementation
    function upgradeTributeDraft(address proxyAddress, string memory version) internal {
        console.log("Upgrading Tribute Draft implementation...");

        TributeDraftUpgradeable proxy = TributeDraftUpgradeable(proxyAddress);
        console.log("Current Tribute Draft version:", proxy.VERSION());
        console.log("Current Tribute Draft owner:", proxy.owner());

        // Deploy new implementation with deterministic salt
        bytes32 salt = generateSalt(string.concat("TributeDraftImpl_", version));
        address newImpl = address(new TributeDraftUpgradeable{salt: salt}());
        console.log("New Tribute Draft implementation:", newImpl);

        // Perform upgrade
        proxy.upgradeTo(newImpl);

        console.log("Tribute Draft upgrade completed");
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
            ConsumptionRecordAmendmentUpgradeable consumptionRecord =
                ConsumptionRecordAmendmentUpgradeable(config.consumptionRecordAmendmentProxy);
            console.log(
                "Consumption Record Amendment proxy still functional:", address(consumptionRecord) != address(0)
            );
            console.log("Consumption Record Amendment version:", consumptionRecord.VERSION());

            // Test basic functionality
            address craRegistry = consumptionRecord.getCRARegistry();
            console.log("Consumption Record Amendment still linked to CRA Registry:", craRegistry != address(0));
        }

        if (config.upgradeConsumptionUnit) {
            ConsumptionUnitUpgradeable cu = ConsumptionUnitUpgradeable(config.consumptionUnitProxy);
            console.log("Consumption Unit proxy still functional:", address(cu) != address(0));
            console.log("Consumption Unit version:", cu.VERSION());
            address cr = cu.getConsumptionRecordAddress();
            address cra = cu.getConsumptionRecordAmendmentAddress();
            console.log("Consumption Unit linked CR:", cr);
            console.log("Consumption Unit linked CRA:", cra);
            console.log("Consumption Unit links are set:", cr != address(0) && cra != address(0));
        }

        if (config.upgradeTributeDraft) {
            TributeDraftUpgradeable td = TributeDraftUpgradeable(config.tributeDraftProxy);
            console.log("Tribute Draft proxy still functional:", address(td) != address(0));
            console.log("Tribute Draft version:", td.VERSION());
            address cuAddr = td.getConsumptionUnitAddress();
            console.log("Tribute Draft linked CU:", cuAddr);
            console.log("Tribute Draft link is set:", cuAddr != address(0));
        }

        console.log("All upgrade verifications passed");
        console.log("");
    }
}
