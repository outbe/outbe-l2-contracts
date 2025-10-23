// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {
    ConsumptionRecordAmendmentUpgradeable
} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConsumptionUnitUpgradeable} from "../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {TributeDraftUpgradeable} from "../src/tribute_draft/TributeDraftUpgradeable.sol";

contract PredictAddresses is Script {
    function run() public view {
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

        string memory saltSuffix = vm.envOr("SALT_SUFFIX", string("v1"));
        bool useTimestampSalt = vm.envOr("USE_TIMESTAMP_SALT", false);

        if (useTimestampSalt) {
            saltSuffix = vm.toString(block.timestamp);
        }

        console.log("=== CREATE2 Address Predictions ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Salt suffix:", saltSuffix);
        console.log("");

        predictUpgradeableAddresses(deployer, saltSuffix);
    }

    function predictUpgradeableAddresses(address deployer, string memory saltSuffix) internal pure {
        console.log("=== Upgradeable Contracts (UUPS Proxy Pattern) ===");

        // Generate salt strings matching DeployUpgradeable script
        string memory craImplSalt = string.concat("CRARegistryImpl_", saltSuffix);
        string memory craProxySalt = string.concat("CRARegistryProxy_", saltSuffix);
        string memory crImplSalt = string.concat("ConsumptionRecordImpl_", saltSuffix);
        string memory crProxySalt = string.concat("ConsumptionRecordProxy_", saltSuffix);
        string memory crAImplSalt = string.concat("ConsumptionRecordAmendmentImpl_", saltSuffix);
        string memory crAProxySalt = string.concat("ConsumptionRecordAmendmentProxy_", saltSuffix);
        string memory cuImplSalt = string.concat("ConsumptionUnitImpl_", saltSuffix);
        string memory cuProxySalt = string.concat("ConsumptionUnitProxy_", saltSuffix);
        string memory tdImplSalt = string.concat("TributeDraftImpl_", saltSuffix);
        string memory tdProxySalt = string.concat("TributeDraftProxy_", saltSuffix);

        // Convert to bytes32
        bytes32 craImplSaltBytes = keccak256(abi.encodePacked(craImplSalt));
        bytes32 craProxySaltBytes = keccak256(abi.encodePacked(craProxySalt));
        bytes32 crImplSaltBytes = keccak256(abi.encodePacked(crImplSalt));
        bytes32 crProxySaltBytes = keccak256(abi.encodePacked(crProxySalt));
        bytes32 crAImplSaltBytes = keccak256(abi.encodePacked(crAImplSalt));
        bytes32 crAProxySaltBytes = keccak256(abi.encodePacked(crAProxySalt));
        bytes32 cuImplSaltBytes = keccak256(abi.encodePacked(cuImplSalt));
        bytes32 cuProxySaltBytes = keccak256(abi.encodePacked(cuProxySalt));
        bytes32 tdImplSaltBytes = keccak256(abi.encodePacked(tdImplSalt));
        bytes32 tdProxySaltBytes = keccak256(abi.encodePacked(tdProxySalt));

        // Predict implementation addresses
        address predictedCraImpl = vm.computeCreate2Address(
            craImplSaltBytes, keccak256(type(CRARegistryUpgradeable).creationCode), CREATE2_FACTORY
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

        // Predict proxy addresses
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

        bytes memory crAmendmentInitData =
            abi.encodeWithSignature("initialize(address,address)", predictedCraProxy, deployer);
        bytes memory crAProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCrAImpl, crAmendmentInitData));
        address predictedCrAProxy =
            vm.computeCreate2Address(crAProxySaltBytes, keccak256(crAProxyBytecode), CREATE2_FACTORY);

        // Consumption Unit init and proxy
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

        // Tribute Draft init and proxy
        bytes memory tributeDraftInitData = abi.encodeWithSignature("initialize(address)", predictedCuProxy);
        bytes memory tdProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedTdImpl, tributeDraftInitData));
        address predictedTdProxy =
            vm.computeCreate2Address(tdProxySaltBytes, keccak256(tdProxyBytecode), CREATE2_FACTORY);

        // Display results
        console.log("CRA Registry Implementation:");
        console.log("- Salt string:", craImplSalt);
        console.log("- Salt bytes32:", vm.toString(craImplSaltBytes));
        console.log("- Predicted address:", predictedCraImpl);
        console.log("");

        console.log("CRA Registry Proxy (Main Contract):");
        console.log("- Salt string:", craProxySalt);
        console.log("- Salt bytes32:", vm.toString(craProxySaltBytes));
        console.log("- Predicted address:", predictedCraProxy);
        console.log("");

        console.log("Consumption Record Implementation:");
        console.log("- Salt string:", crImplSalt);
        console.log("- Salt bytes32:", vm.toString(crImplSaltBytes));
        console.log("- Predicted address:", predictedCrImpl);
        console.log("");

        console.log("Consumption Record Proxy (Main Contract):");
        console.log("- Salt string:", crProxySalt);
        console.log("- Salt bytes32:", vm.toString(crProxySaltBytes));
        console.log("- Predicted address:", predictedCrProxy);
        console.log("");

        console.log("Consumption Record Amendment Implementation:");
        console.log("- Salt string:", crAImplSalt);
        console.log("- Salt bytes32:", vm.toString(crAImplSaltBytes));
        console.log("- Predicted address:", predictedCrAImpl);
        console.log("");

        console.log("Consumption Record Amendment Proxy (Main Contract):");
        console.log("- Salt string:", crAProxySalt);
        console.log("- Salt bytes32:", vm.toString(crAProxySaltBytes));
        console.log("- Predicted address:", predictedCrAProxy);
        console.log("");

        console.log("Consumption Unit Implementation:");
        console.log("- Salt string:", cuImplSalt);
        console.log("- Salt bytes32:", vm.toString(cuImplSaltBytes));
        console.log("- Predicted address:", predictedCuImpl);
        console.log("");

        console.log("Consumption Unit Proxy (Main Contract):");
        console.log("- Salt string:", cuProxySalt);
        console.log("- Salt bytes32:", vm.toString(cuProxySaltBytes));
        console.log("- Predicted address:", predictedCuProxy);
        console.log("");

        console.log("Tribute Draft Implementation:");
        console.log("- Salt string:", tdImplSalt);
        console.log("- Salt bytes32:", vm.toString(tdImplSaltBytes));
        console.log("- Predicted address:", predictedTdImpl);
        console.log("");

        console.log("Tribute Draft Proxy (Main Contract):");
        console.log("- Salt string:", tdProxySalt);
        console.log("- Salt bytes32:", vm.toString(tdProxySaltBytes));
        console.log("- Predicted address:", predictedTdProxy);
        console.log("");

        console.log("=== Summary ===");
        console.log("Implementation Addresses (for upgrades):");
        console.log("- CRA Registry Impl:      ", predictedCraImpl);
        console.log("- Consumption Record Impl:", predictedCrImpl);
        console.log("- CR Amendment Impl:      ", predictedCrAImpl);
        console.log("- Consumption Unit Impl:  ", predictedCuImpl);
        console.log("- Tribute Draft Impl:     ", predictedTdImpl);
        console.log("");
        console.log("Proxy Addresses (use these for interactions):");
        console.log("- CRA Registry:      ", predictedCraProxy);
        console.log("- Consumption Record:", predictedCrProxy);
        console.log("- CR Amendment:      ", predictedCrAProxy);
        console.log("- Consumption Unit:  ", predictedCuProxy);
        console.log("- Tribute Draft:     ", predictedTdProxy);
        console.log("");

        console.log("Environment variables:");
        console.log("export CRA_REGISTRY_ADDRESS=", predictedCraProxy);
        console.log("export CONSUMPTION_RECORD_ADDRESS=", predictedCrProxy);
        console.log("export CONSUMPTION_RECORD_AMENDMENT_ADDRESS=", predictedCrAProxy);
        console.log("export CONSUMPTION_UNIT_ADDRESS=", predictedCuProxy);
        console.log("export TRIBUTE_DRAFT_ADDRESS=", predictedTdProxy);
        console.log("export CRA_REGISTRY_IMPL=", predictedCraImpl);
        console.log("export CONSUMPTION_RECORD_IMPL=", predictedCrImpl);
        console.log("export CONSUMPTION_RECORD_AMENDMENT_IMPL=", predictedCrAImpl);
        console.log("export CONSUMPTION_UNIT_IMPL=", predictedCuImpl);
        console.log("export TRIBUTE_DRAFT_IMPL=", predictedTdImpl);
    }

    function computeCreate2Address(bytes32 salt, bytes32 bytecodeHash, address deployer)
        internal
        pure
        override
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash)))));
    }
}
