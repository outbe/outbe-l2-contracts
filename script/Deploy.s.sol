// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CRARegistry} from "../src/cra_registry/CRARegistry.sol";
import {ConsumptionRecord} from "../src/consumption_record/ConsumptionRecord.sol";

/// @title Deploy Script
/// @notice Deployment script for CRA Registry and Consumption Record contracts
/// @dev Deploys contracts in correct order with proper initialization
contract Deploy is Script {
    /// @notice CRA Registry contract instance
    CRARegistry public craRegistry;

    /// @notice Consumption Record contract instance
    ConsumptionRecord public consumptionRecord;

    /// @notice Deployment configuration
    struct DeploymentConfig {
        address deployer;
        bool verify;
        bool setupInitialCras;
    }

    /// @notice Initial CRAs to register (optional)
    struct InitialCra {
        address craAddress;
        string name;
    }

    function setUp() public {}

    /// @notice Main deployment function
    /// @dev Deploys both contracts and optionally sets up initial CRAs
    function run() public {
        // Load deployment parameters - try environment first, then use default for testing
        uint256 deployerPrivateKey;

        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // Use default Anvil private key for testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("WARNING: Using default Anvil private key for testing");
        }

        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Outbe L2 Contracts Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");

        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");

        if (balance < 0.01 ether) {
            console.log("WARNING: Low balance, deployment may fail");
        }
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy CRA Registry first
        console.log("Deploying CRA Registry...");
        craRegistry = new CRARegistry();
        console.log("CRA Registry deployed at:", address(craRegistry));
        console.log("CRA Registry owner:", craRegistry.getOwner());
        console.log("");

        // Deploy Consumption Record with CRA Registry address
        console.log("Deploying Consumption Record...");
        consumptionRecord = new ConsumptionRecord(address(craRegistry));
        console.log("Consumption Record deployed at:", address(consumptionRecord));
        console.log("Consumption Record owner:", consumptionRecord.getOwner());
        console.log("Consumption Record CRA Registry:", consumptionRecord.getCraRegistry());
        console.log("");

        // Setup initial CRAs if environment variable is set
        if (vm.envOr("SETUP_INITIAL_CRAS", false)) {
            setupInitialCras();
        }

        vm.stopBroadcast();

        // Post-deployment verification
        verifyDeployment(deployer);

        // Log final deployment summary
        logDeploymentSummary();
    }

    /// @notice Setup initial CRAs for testing/demo purposes
    /// @dev Only called if SETUP_INITIAL_CRAS=true in environment
    function setupInitialCras() internal {
        console.log("Setting up initial CRAs...");

        // Example CRAs - replace with actual addresses as needed
        InitialCra[] memory initialCras = new InitialCra[](2);
        initialCras[0] = InitialCra({
            craAddress: vm.envOr("INITIAL_CRA_1", address(0x1111111111111111111111111111111111111111)),
            name: vm.envOr("INITIAL_CRA_1_NAME", string("Demo CRA 1"))
        });
        initialCras[1] = InitialCra({
            craAddress: vm.envOr("INITIAL_CRA_2", address(0x2222222222222222222222222222222222222222)),
            name: vm.envOr("INITIAL_CRA_2_NAME", string("Demo CRA 2"))
        });

        for (uint256 i = 0; i < initialCras.length; i++) {
            if (initialCras[i].craAddress != address(0)) {
                craRegistry.registerCra(initialCras[i].craAddress, initialCras[i].name);
                console.log("Registered CRA:", initialCras[i].craAddress, "as", initialCras[i].name);

                // Verify registration
                bool isActive = craRegistry.isCraActive(initialCras[i].craAddress);
                console.log("CRA active status:", isActive);
            }
        }
        console.log("");
    }

    /// @notice Verify deployment was successful
    /// @dev Performs basic checks on deployed contracts
    /// @param expectedOwner The expected owner address
    function verifyDeployment(address expectedOwner) internal view {
        console.log("=== Deployment Verification ===");

        // Check CRA Registry
        require(address(craRegistry) != address(0), "CRA Registry deployment failed");
        require(craRegistry.getOwner() == expectedOwner, "CRA Registry owner incorrect");
        console.log("CRA Registry verification passed");

        // Check Consumption Record
        require(address(consumptionRecord) != address(0), "Consumption Record deployment failed");
        require(consumptionRecord.getOwner() == expectedOwner, "Consumption Record owner incorrect");
        require(consumptionRecord.getCraRegistry() == address(craRegistry), "CRA Registry linkage incorrect");
        console.log("Consumption Record verification passed");

        // Check contract versions
        string memory craVersion = craRegistry.VERSION();
        string memory crVersion = consumptionRecord.VERSION();
        console.log("CRA Registry version:", craVersion);
        console.log("Consumption Record version:", crVersion);
        console.log("");
    }

    /// @notice Log deployment summary with all important information
    function logDeploymentSummary() internal view {
        console.log("=== Deployment Summary ===");
        console.log("Network:", getNetworkName());
        console.log("Deployment completed successfully!");
        console.log("");
        console.log("Contract Addresses:");
        console.log("- CRA Registry:      ", address(craRegistry));
        console.log("- Consumption Record:", address(consumptionRecord));
        console.log("");
        console.log("Contract Owners:");
        console.log("- CRA Registry:      ", craRegistry.getOwner());
        console.log("- Consumption Record:", consumptionRecord.getOwner());
        console.log("");
        console.log("Configuration:");
        console.log("- CR -> CRA Registry:", consumptionRecord.getCraRegistry());
        console.log("");

        if (vm.envOr("SETUP_INITIAL_CRAS", false)) {
            address[] memory allCras = craRegistry.getAllCras();
            console.log("Initial CRAs registered:", allCras.length);
            for (uint256 i = 0; i < allCras.length; i++) {
                console.log("- CRA", i + 1, ":", allCras[i]);
            }
            console.log("");
        }

        console.log("Next Steps:");
        console.log("1. Verify contracts on block explorer (if on public network)");
        console.log("2. Register CRAs using registerCra(address, string)");
        console.log("3. CRAs can submit consumption records using submit()");
        console.log("4. Update environment variables with deployed addresses");
        console.log("");
        console.log("Environment Variables for .env:");
        console.log("CRA_REGISTRY_ADDRESS=", address(craRegistry));
        console.log("CONSUMPTION_RECORD_ADDRESS=", address(consumptionRecord));
    }

    /// @notice Get network name based on chain ID
    /// @return Network name string
    function getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;

        if (chainId == 424242) return "Outbe Dev Net";
        if (chainId == 512512) return "Outbe Private Net";
        if (chainId == 1) return "Mainnet";
        if (chainId == 11155111) return "Sepolia";
        if (chainId == 17000) return "Holesky";
        if (chainId == 137) return "Polygon";
        if (chainId == 42161) return "Arbitrum One";
        if (chainId == 10) return "Optimism";
        if (chainId == 8453) return "Base";
        if (chainId == 31337) return "Foundry Anvil";

        return string(abi.encodePacked("Unknown (", vm.toString(chainId), ")"));
    }
}

/// @title Quick Deploy Script
/// @notice Simplified deployment script for testing
contract QuickDeploy is Script {
    function run() public {
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        CRARegistry craRegistry = new CRARegistry();
        ConsumptionRecord consumptionRecord = new ConsumptionRecord(address(craRegistry));

        console.log("CRA Registry:", address(craRegistry));
        console.log("Consumption Record:", address(consumptionRecord));

        vm.stopBroadcast();
    }
}
