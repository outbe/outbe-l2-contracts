// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

    function predictUpgradeableAddresses(address deployer, string memory saltSuffix) internal view {
        console.log("=== Upgradeable Contracts (UUPS Proxy Pattern) ===");

        // Generate salt strings matching DeployUpgradeable script
        string memory craImplSalt = string.concat("CRARegistryImpl_", saltSuffix);
        string memory craProxySalt = string.concat("CRARegistryProxy_", saltSuffix);
        string memory crImplSalt = string.concat("ConsumptionRecordImpl_", saltSuffix);
        string memory crProxySalt = string.concat("ConsumptionRecordProxy_", saltSuffix);

        // Convert to bytes32
        bytes32 craImplSaltBytes = keccak256(abi.encodePacked(craImplSalt));
        bytes32 craProxySaltBytes = keccak256(abi.encodePacked(craProxySalt));
        bytes32 crImplSaltBytes = keccak256(abi.encodePacked(crImplSalt));
        bytes32 crProxySaltBytes = keccak256(abi.encodePacked(crProxySalt));

        // Predict implementation addresses
        address predictedCraImpl = vm.computeCreate2Address(
            craImplSaltBytes, keccak256(type(CRARegistryUpgradeable).creationCode), CREATE2_FACTORY
        );

        address predictedCrImpl = vm.computeCreate2Address(
            crImplSaltBytes, keccak256(type(ConsumptionRecordUpgradeable).creationCode), CREATE2_FACTORY
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

        console.log("=== Summary ===");
        console.log("Implementation Addresses (for upgrades):");
        console.log("- CRA Registry Impl:      ", predictedCraImpl);
        console.log("- Consumption Record Impl:", predictedCrImpl);
        console.log("");
        console.log("Proxy Addresses (use these for interactions):");
        console.log("- CRA Registry:      ", predictedCraProxy);
        console.log("- Consumption Record:", predictedCrProxy);
        console.log("");

        console.log("Environment variables:");
        console.log("export CRA_REGISTRY_ADDRESS=", predictedCraProxy);
        console.log("export CONSUMPTION_RECORD_ADDRESS=", predictedCrProxy);
        console.log("export CRA_REGISTRY_IMPL=", predictedCraImpl);
        console.log("export CONSUMPTION_RECORD_IMPL=", predictedCrImpl);
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
