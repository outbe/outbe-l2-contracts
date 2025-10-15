// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {TributeDraftUpgradeable} from "../src/tribute_draft/TributeDraftUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title DeployUpgradeable Script
/// @notice Deployment script for upgradeable CRA Registry and Consumption Record contracts
/// @dev Deploys implementation contracts and creates proxies with deterministic addresses
contract DeployUpgradeable is Script {
    /// @notice CRA Registry proxy instance
    CRARegistryUpgradeable public craRegistry;

    /// @notice Consumption Record proxy instance
    ConsumptionRecordUpgradeable public consumptionRecord;
    /// @notice Consumption Unit proxy instance
    ConsumptionUnitUpgradeable public consumptionUnit;
    /// @notice Tribute Draft proxy instance
    TributeDraftUpgradeable public tributeDraft;

    /// @notice Implementation contracts
    address public craRegistryImpl;
    address public consumptionRecordImpl;
    address public consumptionUnitImpl;
    address public tributeDraftImpl;

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
    /// @dev Deploys implementation contracts and creates proxies
    function run() public {
        // Load deployment parameters
        uint256 deployerPrivateKey;

        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // Use default Anvil private key for testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("WARNING: Using default Anvil private key for testing");
        }

        address deployer = vm.addr(deployerPrivateKey);

        // Load or generate salt suffix for CREATE2 deterministic addresses
        string memory saltSuffix = vm.envOr("SALT_SUFFIX", string("v1"));
        bool useTimestampSalt = vm.envOr("USE_TIMESTAMP_SALT", false);

        if (useTimestampSalt) {
            saltSuffix = vm.toString(block.timestamp);
            console.log("Using timestamp salt:", saltSuffix);
        }

        console.log("=== Outbe L2 Upgradeable Contracts Deployment ===");
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

        // Generate salt strings
        string memory craImplSalt = string.concat("CRARegistryImpl_", saltSuffix);
        string memory craProxySalt = string.concat("CRARegistryProxy_", saltSuffix);
        string memory crImplSalt = string.concat("ConsumptionRecordImpl_", saltSuffix);
        string memory crProxySalt = string.concat("ConsumptionRecordProxy_", saltSuffix);
        string memory cuImplSalt = string.concat("ConsumptionUnitImpl_", saltSuffix);
        string memory cuProxySalt = string.concat("ConsumptionUnitProxy_", saltSuffix);
        string memory tdImplSalt = string.concat("TributeDraftImpl_", saltSuffix);
        string memory tdProxySalt = string.concat("TributeDraftProxy_", saltSuffix);

        console.log("Using salt suffix:", saltSuffix);

        // Convert salt strings to bytes32
        bytes32 craImplSaltBytes = keccak256(abi.encodePacked(craImplSalt));
        bytes32 craProxySaltBytes = keccak256(abi.encodePacked(craProxySalt));
        bytes32 crImplSaltBytes = keccak256(abi.encodePacked(crImplSalt));
        bytes32 crProxySaltBytes = keccak256(abi.encodePacked(crProxySalt));
        bytes32 cuImplSaltBytes = keccak256(abi.encodePacked(cuImplSalt));
        bytes32 cuProxySaltBytes = keccak256(abi.encodePacked(cuProxySalt));
        bytes32 tdImplSaltBytes = keccak256(abi.encodePacked(tdImplSalt));
        bytes32 tdProxySaltBytes = keccak256(abi.encodePacked(tdProxySalt));

        // Check if contracts already exist at predicted addresses
        address predictedCraImpl = vm.computeCreate2Address(
            craImplSaltBytes, keccak256(type(CRARegistryUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedCrImpl = vm.computeCreate2Address(
            crImplSaltBytes, keccak256(type(ConsumptionRecordUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedCuImpl = vm.computeCreate2Address(
            cuImplSaltBytes, keccak256(type(ConsumptionUnitUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedTdImpl = vm.computeCreate2Address(
            tdImplSaltBytes, keccak256(type(TributeDraftUpgradeable).creationCode), CREATE2_FACTORY
        );

        // For proxy addresses, we need to compute with init data
        bytes memory craRegistryInitData = abi.encodeWithSignature("initialize(address)", deployer);
        bytes memory craProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCraImpl, craRegistryInitData));
        address predictedCraProxy =
            vm.computeCreate2Address(craProxySaltBytes, keccak256(craProxyBytecode), CREATE2_FACTORY);

        bytes memory consumptionRecordInitData =
            abi.encodeWithSignature("initialize(address,address)", predictedCraProxy, deployer);
        bytes memory crProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCrImpl, consumptionRecordInitData));
        address predictedCrProxy =
            vm.computeCreate2Address(crProxySaltBytes, keccak256(crProxyBytecode), CREATE2_FACTORY);

        bytes memory consumptionUnitInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", predictedCraProxy, deployer, predictedCrProxy
        );
        bytes memory cuProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCuImpl, consumptionUnitInitData));
        address predictedCuProxy =
            vm.computeCreate2Address(cuProxySaltBytes, keccak256(cuProxyBytecode), CREATE2_FACTORY);

        // Tribute Draft init and predicted proxy
        bytes memory tributeDraftInitData = abi.encodeWithSignature("initialize(address)", predictedCuProxy);
        bytes memory tdProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedTdImpl, tributeDraftInitData));
        address predictedTdProxy =
            vm.computeCreate2Address(tdProxySaltBytes, keccak256(tdProxyBytecode), CREATE2_FACTORY);

        // Check for existing deployments
        bool hasExistingContracts = false;

        if (predictedCraImpl.code.length > 0) {
            console.log("WARNING: CRA Registry implementation already exists at:", predictedCraImpl);
            hasExistingContracts = true;
        }

        if (predictedCrImpl.code.length > 0) {
            console.log("WARNING: Consumption Record implementation already exists at:", predictedCrImpl);
            hasExistingContracts = true;
        }

        if (predictedCuImpl.code.length > 0) {
            console.log("WARNING: Consumption Unit implementation already exists at:", predictedCuImpl);
            hasExistingContracts = true;
        }

        if (predictedTdImpl.code.length > 0) {
            console.log("WARNING: Tribute Draft implementation already exists at:", predictedTdImpl);
            hasExistingContracts = true;
        }

        if (predictedCraProxy.code.length > 0) {
            console.log("WARNING: CRA Registry proxy already exists at:", predictedCraProxy);
            hasExistingContracts = true;
        }

        if (predictedCrProxy.code.length > 0) {
            console.log("WARNING: Consumption Record proxy already exists at:", predictedCrProxy);
            hasExistingContracts = true;
        }

        if (predictedCuProxy.code.length > 0) {
            console.log("WARNING: Consumption Unit proxy already exists at:", predictedCuProxy);
            hasExistingContracts = true;
        }

        if (predictedTdProxy.code.length > 0) {
            console.log("WARNING: Tribute Draft proxy already exists at:", predictedTdProxy);
            hasExistingContracts = true;
        }

        if (hasExistingContracts) {
            console.log("ERROR: Some contracts already exist at predicted addresses!");
            console.log("Solutions:");
            console.log("1. Use different SALT_SUFFIX environment variable");
            console.log("2. Use USE_TIMESTAMP_SALT=true for unique salt");
            console.log("3. If intentional, use UpgradeImplementations.s.sol instead");
            console.log("");
            revert("Contracts already deployed at predicted addresses");
        }

        // Deploy CRA Registry implementation
        console.log("Deploying CRA Registry implementation...");
        craRegistryImpl = address(new CRARegistryUpgradeable{salt: craImplSaltBytes}());
        console.log("CRA Registry implementation:", craRegistryImpl);

        // Deploy CRA Registry proxy
        console.log("Deploying CRA Registry proxy...");
        address craRegistryProxy =
            address(new ERC1967Proxy{salt: craProxySaltBytes}(craRegistryImpl, craRegistryInitData));
        craRegistry = CRARegistryUpgradeable(craRegistryProxy);
        console.log("CRA Registry proxy:", address(craRegistry));
        console.log("CRA Registry owner:", craRegistry.getOwner());
        console.log("");

        // Deploy Consumption Record implementation
        console.log("Deploying Consumption Record implementation...");
        consumptionRecordImpl = address(new ConsumptionRecordUpgradeable{salt: crImplSaltBytes}());
        console.log("Consumption Record implementation:", consumptionRecordImpl);

        // Deploy Consumption Record proxy
        console.log("Deploying Consumption Record proxy...");
        bytes memory crInitData = abi.encodeWithSignature("initialize(address,address)", address(craRegistry), deployer);
        address consumptionRecordProxy =
            address(new ERC1967Proxy{salt: crProxySaltBytes}(consumptionRecordImpl, crInitData));
        consumptionRecord = ConsumptionRecordUpgradeable(consumptionRecordProxy);
        console.log("Consumption Record proxy:", address(consumptionRecord));
        console.log("Consumption Record owner:", consumptionRecord.getOwner());
        console.log("Consumption Record CRA Registry:", consumptionRecord.getCRARegistry());
        console.log("");

        // Deploy Consumption Unit implementation
        console.log("Deploying Consumption Unit implementation...");
        consumptionUnitImpl = address(new ConsumptionUnitUpgradeable{salt: cuImplSaltBytes}());
        console.log("Consumption Unit implementation:", consumptionUnitImpl);

        // Deploy Consumption Unit proxy
        console.log("Deploying Consumption Unit proxy...");
        bytes memory cuInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", address(craRegistry), deployer, address(consumptionRecord)
        );
        address consumptionUnitProxy =
            address(new ERC1967Proxy{salt: cuProxySaltBytes}(consumptionUnitImpl, cuInitData));
        consumptionUnit = ConsumptionUnitUpgradeable(consumptionUnitProxy);
        console.log("Consumption Unit proxy:", address(consumptionUnit));
        console.log("Consumption Unit owner:", consumptionUnit.getOwner());
        console.log("Consumption Unit CRA Registry:", consumptionUnit.getCRARegistry());
        console.log("Consumption Unit CR Address:", consumptionUnit.getConsumptionRecordAddress());
        console.log("");

        // Deploy Tribute Draft implementation
        console.log("Deploying Tribute Draft implementation...");
        tributeDraftImpl = address(new TributeDraftUpgradeable{salt: tdImplSaltBytes}());
        console.log("Tribute Draft implementation:", tributeDraftImpl);

        // Deploy Tribute Draft proxy
        console.log("Deploying Tribute Draft proxy...");
        bytes memory tdInitData = abi.encodeWithSignature("initialize(address)", address(consumptionUnit));
        address tributeDraftProxy = address(new ERC1967Proxy{salt: tdProxySaltBytes}(tributeDraftImpl, tdInitData));
        tributeDraft = TributeDraftUpgradeable(tributeDraftProxy);
        console.log("Tribute Draft proxy:", address(tributeDraft));
        console.log("Tribute Draft CU:", tributeDraft.getConsumptionUnitAddress());
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
                craRegistry.registerCRA(initialCras[i].craAddress, initialCras[i].name);
                console.log("Registered CRA:", initialCras[i].craAddress, "as", initialCras[i].name);

                // Verify registration
                bool isActive = craRegistry.isCRAActive(initialCras[i].craAddress);
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
        require(consumptionRecord.getCRARegistry() == address(craRegistry), "CRA Registry linkage incorrect");
        console.log("Consumption Record verification passed");

        // Check Consumption Unit
        require(address(consumptionUnit) != address(0), "Consumption Unit deployment failed");
        require(consumptionUnit.getOwner() == expectedOwner, "Consumption Unit owner incorrect");
        require(consumptionUnit.getCRARegistry() == address(craRegistry), "CU CRA Registry linkage incorrect");
        console.log("Consumption Unit verification passed");

        // Check Tribute Draft
        require(address(tributeDraft) != address(0), "Tribute Draft deployment failed");
        require(tributeDraft.getConsumptionUnitAddress() == address(consumptionUnit), "TD CU linkage incorrect");
        console.log("Tribute Draft verification passed");

        // Check contract versions
        string memory craVersion = craRegistry.VERSION();
        string memory crVersion = consumptionRecord.VERSION();
        string memory cuVersion = consumptionUnit.VERSION();
        string memory tdVersion = tributeDraft.VERSION();
        console.log("CRA Registry version:", craVersion);
        console.log("Consumption Record version:", crVersion);
        console.log("Consumption Unit version:", cuVersion);
        console.log("Tribute Draft version:", tdVersion);
        console.log("");
    }

    /// @notice Log deployment summary with all important information
    function logDeploymentSummary() internal view {
        console.log("=== Deployment Summary ===");
        console.log("Network:", getNetworkName());
        console.log("Deployment completed successfully!");
        console.log("");
        console.log("Implementation Addresses:");
        console.log("- CRA Registry Impl:      ", craRegistryImpl);
        console.log("- Consumption Record Impl:", consumptionRecordImpl);
        console.log("- Consumption Unit Impl:  ", consumptionUnitImpl);
        console.log("- Tribute Draft Impl:     ", tributeDraftImpl);
        console.log("");
        console.log("Proxy Addresses (Use these for interactions):");
        console.log("- CRA Registry:      ", address(craRegistry));
        console.log("- Consumption Record:", address(consumptionRecord));
        console.log("- Consumption Unit:  ", address(consumptionUnit));
        console.log("- Tribute Draft:     ", address(tributeDraft));
        console.log("");
        console.log("Contract Owners:");
        console.log("- CRA Registry:      ", craRegistry.getOwner());
        console.log("- Consumption Record:", consumptionRecord.getOwner());
        console.log("- Consumption Unit:  ", consumptionUnit.getOwner());
        // Tribute Draft is Ownable but no owner getter; no direct owner method in TD, skip owner here
        console.log("");
        console.log("Configuration:");
        console.log("- CR -> CRA Registry:", consumptionRecord.getCRARegistry());
        console.log("- CU -> CRA Registry:", consumptionUnit.getCRARegistry());
        console.log("- TD -> Consumption Unit:", tributeDraft.getConsumptionUnitAddress());
        console.log("");

        if (vm.envOr("SETUP_INITIAL_CRAS", false)) {
            address[] memory allCras = craRegistry.getAllCRAs();
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
        console.log("4. Use proxy addresses for all interactions");
        console.log("5. Implementations can be upgraded while preserving proxy addresses");
        console.log("");
        console.log("Environment Variables for .env:");
        console.log("CRA_REGISTRY_ADDRESS=", address(craRegistry));
        console.log("CONSUMPTION_RECORD_ADDRESS=", address(consumptionRecord));
        console.log("CONSUMPTION_UNIT_ADDRESS=", address(consumptionUnit));
        console.log("TRIBUTE_DRAFT_ADDRESS=", address(tributeDraft));
        console.log("CRA_REGISTRY_IMPL=", craRegistryImpl);
        console.log("CONSUMPTION_RECORD_IMPL=", consumptionRecordImpl);
        console.log("CONSUMPTION_UNIT_IMPL=", consumptionUnitImpl);
        console.log("TRIBUTE_DRAFT_IMPL=", tributeDraftImpl);
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
