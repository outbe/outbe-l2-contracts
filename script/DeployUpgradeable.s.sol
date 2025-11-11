// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OutbeScriptBase} from "./OutbeScriptBase.sol";
import {
    ConsumptionRecordAmendmentUpgradeable
} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console} from "forge-std/Script.sol";
import {TributeDraftUpgradeable} from "../src/tribute_draft/TributeDraftUpgradeable.sol";

/// @title DeployUpgradeable Script
/// @notice Deployment script for upgradeable CRA Registry and Consumption Record contracts
/// @dev Deploys implementation contracts and creates proxies with deterministic addresses
contract DeployUpgradeable is OutbeScriptBase {
    /// @notice CRA Registry proxy instance
    CRARegistryUpgradeable public craRegistry;

    /// @notice Consumption Record proxy instance
    ConsumptionRecordUpgradeable public consumptionRecord;
    /// @notice Consumption Unit proxy instance
    ConsumptionUnitUpgradeable public consumptionUnit;
    /// @notice Consumption Record Amendment proxy instance
    ConsumptionRecordAmendmentUpgradeable public consumptionRecordAmendment;
    /// @notice Tribute Draft proxy instance
    TributeDraftUpgradeable public tributeDraft;

    /// @notice Implementation contracts
    address public craRegistryImpl;
    address public consumptionRecordImpl;
    address public consumptionRecordAmendmentImpl;
    address public consumptionUnitImpl;
    address public tributeDraftImpl;

    /// @notice Initial CRAs to register (optional)
    struct InitialCra {
        address craAddress;
        string name;
    }

    /// @notice Main deployment function
    /// @dev Deploys implementation contracts and creates proxies
    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        // Generate salt
        bytes32 craRegistryImplSaltBytes = generateSalt("CRARegistryImpl_");
        bytes32 craRegistryProxySaltBytes = generateSalt("CRARegistryProxy_");
        bytes32 crImplSaltBytes = generateSalt("ConsumptionRecordImpl_");
        bytes32 crProxySaltBytes = generateSalt("ConsumptionRecordProxy_");
        bytes32 crAImplSaltBytes = generateSalt("ConsumptionRecordAmendmentImpl_");
        bytes32 crAProxySaltBytes = generateSalt("ConsumptionRecordAmendmentProxy_");
        bytes32 cuImplSaltBytes = generateSalt("ConsumptionUnitImpl_");
        bytes32 cuProxySaltBytes = generateSalt("ConsumptionUnitProxy_");
        bytes32 tdImplSaltBytes = generateSalt("TributeDraftImpl_");
        bytes32 tdProxySaltBytes = generateSalt("TributeDraftProxy_");

        // Check if contracts already exist at predicted addresses
        address predictedCraRegistryImpl = vm.computeCreate2Address(
            craRegistryImplSaltBytes, keccak256(type(CRARegistryUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedCrImpl = vm.computeCreate2Address(
            crImplSaltBytes, keccak256(type(ConsumptionRecordUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedCrAImpl = vm.computeCreate2Address(
            crAImplSaltBytes, keccak256(type(ConsumptionRecordAmendmentUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedCuImpl = vm.computeCreate2Address(
            cuImplSaltBytes, keccak256(type(ConsumptionUnitUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedTdImpl = vm.computeCreate2Address(
            tdImplSaltBytes, keccak256(type(TributeDraftUpgradeable).creationCode), CREATE2_FACTORY
        );

        // For proxy addresses, we need to compute with init data
        bytes memory craRegistryInitData = abi.encodeWithSignature("initialize(address)", deployer);
        bytes memory craProxyBytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode, abi.encode(predictedCraRegistryImpl, craRegistryInitData)
        );
        address predictedCraProxy =
            vm.computeCreate2Address(craRegistryProxySaltBytes, keccak256(craProxyBytecode), CREATE2_FACTORY);

        bytes memory consumptionRecordInitData =
            abi.encodeWithSignature("initialize(address,address)", predictedCraProxy, deployer);
        bytes memory crProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCrImpl, consumptionRecordInitData));
        address predictedCrProxy =
            vm.computeCreate2Address(crProxySaltBytes, keccak256(crProxyBytecode), CREATE2_FACTORY);

        bytes memory crAmendmentInitData =
            abi.encodeWithSignature("initialize(address,address)", predictedCraProxy, deployer);
        bytes memory crAProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCrAImpl, crAmendmentInitData));
        address predictedCrAProxy =
            vm.computeCreate2Address(crAProxySaltBytes, keccak256(crAProxyBytecode), CREATE2_FACTORY);

        bytes memory consumptionUnitInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            predictedCraProxy,
            deployer,
            predictedCrProxy,
            predictedCrAProxy
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

        if (predictedCraRegistryImpl.code.length > 0) {
            console.log("WARNING: CRA Registry implementation already exists at:", predictedCraRegistryImpl);
            hasExistingContracts = true;
        }

        if (predictedCrImpl.code.length > 0) {
            console.log("WARNING: Consumption Record implementation already exists at:", predictedCrImpl);
            hasExistingContracts = true;
        }

        if (predictedCrAImpl.code.length > 0) {
            console.log("WARNING: CR Amendment implementation already exists at:", predictedCrAImpl);
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

        if (predictedCrAProxy.code.length > 0) {
            console.log("WARNING: CR Amendment proxy already exists at:", predictedCrAProxy);
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
            console.log("");
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
        craRegistryImpl = address(new CRARegistryUpgradeable{salt: craRegistryImplSaltBytes}());
        console.log("CRA Registry implementation:", craRegistryImpl);

        // Deploy CRA Registry proxy
        console.log("Deploying CRA Registry proxy...");
        address craRegistryProxy =
            address(new ERC1967Proxy{salt: craRegistryProxySaltBytes}(craRegistryImpl, craRegistryInitData));
        craRegistry = CRARegistryUpgradeable(craRegistryProxy);
        console.log("CRA Registry proxy:", address(craRegistry));
        console.log("CRA Registry owner:", craRegistry.owner());
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
        console.log("Consumption Record owner:", consumptionRecord.owner());
        console.log("Consumption Record CRA Registry:", consumptionRecord.getCRARegistry());
        console.log("");

        // Deploy Consumption Record Amendment implementation
        console.log("Deploying CR Amendment implementation...");
        consumptionRecordAmendmentImpl = address(new ConsumptionRecordAmendmentUpgradeable{salt: crAImplSaltBytes}());
        console.log("CR Amendment implementation:", consumptionRecordAmendmentImpl);

        // Deploy Consumption Record Amendment proxy
        console.log("Deploying CR Amendment proxy...");
        bytes memory crAInitData =
            abi.encodeWithSignature("initialize(address,address)", address(craRegistry), deployer);
        address crAmendmentProxy =
            address(new ERC1967Proxy{salt: crAProxySaltBytes}(consumptionRecordAmendmentImpl, crAInitData));
        consumptionRecordAmendment = ConsumptionRecordAmendmentUpgradeable(crAmendmentProxy);
        console.log("CR Amendment proxy:", address(consumptionRecordAmendment));
        console.log("CR Amendment owner:", consumptionRecordAmendment.owner());
        console.log("CR Amendment CRA Registry:", consumptionRecordAmendment.getCRARegistry());
        console.log("");

        // Deploy Consumption Unit implementation
        console.log("Deploying Consumption Unit implementation...");
        consumptionUnitImpl = address(new ConsumptionUnitUpgradeable{salt: cuImplSaltBytes}());
        console.log("Consumption Unit implementation:", consumptionUnitImpl);

        // Deploy Consumption Unit proxy
        console.log("Deploying Consumption Unit proxy...");
        bytes memory cuInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            address(craRegistry),
            deployer,
            address(consumptionRecord),
            address(consumptionRecordAmendment)
        );
        address consumptionUnitProxy =
            address(new ERC1967Proxy{salt: cuProxySaltBytes}(consumptionUnitImpl, cuInitData));
        consumptionUnit = ConsumptionUnitUpgradeable(consumptionUnitProxy);
        console.log("Consumption Unit proxy:", address(consumptionUnit));
        console.log("Consumption Unit owner:", consumptionUnit.owner());
        console.log("Consumption Unit CRA Registry:", consumptionUnit.getCRARegistry());
        console.log("Consumption Unit CR Address:", consumptionUnit.getConsumptionRecordAddress());
        console.log("Consumption Unit CR Amendment Address:", consumptionUnit.getConsumptionRecordAmendmentAddress());
        console.log("");

        // Deploy Tribute Draft implementation
        console.log("Deploying Tribute Draft implementation...");
        tributeDraftImpl = address(new TributeDraftUpgradeable{salt: tdImplSaltBytes}());
        console.log("Tribute Draft implementation:", tributeDraftImpl);

        // Deploy Tribute Draft proxy
        console.log("Deploying Tribute Draft proxy...");
        bytes memory tdInitData =
            abi.encodeWithSignature("initialize(address,address)", address(consumptionUnit), deployer);
        address tributeDraftProxy = address(new ERC1967Proxy{salt: tdProxySaltBytes}(tributeDraftImpl, tdInitData));
        tributeDraft = TributeDraftUpgradeable(tributeDraftProxy);
        console.log("Tribute Draft proxy:", address(tributeDraft));
        console.log("Tribute Draft CU:", tributeDraft.getConsumptionUnitAddress());
        console.log("");

        setupInitialCras();

        vm.stopBroadcast();

        // Post-deployment verification
        verifyDeployment(deployer);

        // Log final deployment summary
        logDeploymentSummary();
    }

    /// @notice Setup initial CRAs from JSON file
    /// @dev Only called if SETUP_INITIAL_CRAS=true in environment
    /// @dev Reads from script/input/init-cras.json
    function setupInitialCras() internal {
        console.log("Setting up initial CRAs");

        // Read and parse JSON file
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/input/init-cras.json");
        string memory json = vm.readFile(path);

        // Parse CRAs array from JSON
        bytes memory crasData = vm.parseJson(json, ".cras");
        InitialCra[] memory initialCras = abi.decode(crasData, (InitialCra[]));

        // Check if CRAs array is empty
        if (initialCras.length == 0) {
            console.log("No CRAs found in init-cras.json, skipping registration");
            console.log("");
            return;
        }

        console.log("Found", initialCras.length, "CRA(s) in init-cras.json");

        // Register each CRA
        for (uint256 i = 0; i < initialCras.length; i++) {
            if (craRegistry.isCRAActive(initialCras[i].craAddress)) {
                console.log("Skipping already registered CRA:", initialCras[i].craAddress);
                continue;
            }
            craRegistry.registerCRA(initialCras[i].craAddress, initialCras[i].name);
            console.log("Registered CRA:", initialCras[i].craAddress, "as", initialCras[i].name);
        }
        console.log("");
    }

    /// @notice Verify deployment was successful
    /// @dev Performs basic checks on deployed contracts
    /// @param expectedOwner The expected owner address
    function verifyDeployment(address expectedOwner) internal view {
        // Check CRA Registry
        require(address(craRegistry) != address(0), "CRA Registry deployment failed");
        require(craRegistry.owner() == expectedOwner, "CRA Registry owner incorrect");
        // Check Consumption Record
        require(address(consumptionRecord) != address(0), "Consumption Record deployment failed");
        require(consumptionRecord.owner() == expectedOwner, "Consumption Record owner incorrect");
        require(consumptionRecord.getCRARegistry() == address(craRegistry), "CRA Registry linkage incorrect");

        // Check Consumption Unit
        require(address(consumptionUnit) != address(0), "Consumption Unit deployment failed");
        require(consumptionUnit.owner() == expectedOwner, "Consumption Unit owner incorrect");
        require(consumptionUnit.getCRARegistry() == address(craRegistry), "CU CRA Registry linkage incorrect");

        // Check Tribute Draft
        require(address(tributeDraft) != address(0), "Tribute Draft deployment failed");
        require(tributeDraft.getConsumptionUnitAddress() == address(consumptionUnit), "TD CU linkage incorrect");
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
        console.log("- Consumption Record Amendment Impl:", consumptionRecordAmendmentImpl);
        console.log("- Consumption Unit Impl:  ", consumptionUnitImpl);
        console.log("- Tribute Draft Impl:     ", tributeDraftImpl);
        console.log("");
        console.log("Proxy Addresses (Use these for interactions):");
        console.log("- CRA Registry:      ", address(craRegistry));
        console.log("- Consumption Record:", address(consumptionRecord));
        console.log("- Consumption Record Amendment:", address(consumptionRecordAmendment));
        console.log("- Consumption Unit:  ", address(consumptionUnit));
        console.log("- Tribute Draft:     ", address(tributeDraft));
        console.log("");
        console.log("Contract Owners:");
        console.log("- CRA Registry:      ", craRegistry.owner());
        console.log("- Consumption Record:", consumptionRecord.owner());
        console.log("- Consumption Record Amendment:", consumptionRecordAmendment.owner());
        console.log("- Consumption Unit:  ", consumptionUnit.owner());
        // Tribute Draft is Ownable but no owner getter; no direct owner method in TD, skip owner here
        console.log("");
        console.log("Configuration:");
        console.log("- CR -> CRA Registry:", consumptionRecord.getCRARegistry());
        console.log("- CR (A) -> CRA Registry:", consumptionRecordAmendment.getCRARegistry());
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

        console.log("Environment Variables:");
        console.log(string.concat("export CRA_REGISTRY_ADDRESS=", vm.toString(address(craRegistry))));
        console.log(string.concat("export CONSUMPTION_RECORD_ADDRESS=", vm.toString(address(consumptionRecord))));
        console.log(
            string.concat(
                "export CONSUMPTION_RECORD_AMENDMENT_ADDRESS=", vm.toString(address(consumptionRecordAmendment))
            )
        );
        console.log(string.concat("export CONSUMPTION_UNIT_ADDRESS=", vm.toString(address(consumptionUnit))));
        console.log(string.concat("export TRIBUTE_DRAFT_ADDRESS=", vm.toString(address(tributeDraft))));
        console.log(string.concat("export CRA_REGISTRY_IMPL=", vm.toString(craRegistryImpl)));
        console.log(string.concat("export CONSUMPTION_RECORD_IMPL=", vm.toString(consumptionRecordImpl)));
        console.log(
            string.concat("export CONSUMPTION_RECORD_AMENDMENT_IMPL=", vm.toString(consumptionRecordAmendmentImpl))
        );
        console.log(string.concat("export CONSUMPTION_UNIT_IMPL=", vm.toString(consumptionUnitImpl)));
        console.log(string.concat("export TRIBUTE_DRAFT_IMPL=", vm.toString(tributeDraftImpl)));
    }
}
