// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/Script.sol";
import {CRARegistryUpgradeable} from "../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {
    ConsumptionRecordAmendmentUpgradeable
} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConsumptionUnitUpgradeable} from "../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {TributeDraftUpgradeable} from "../src/tribute_draft/TributeDraftUpgradeable.sol";
import {OutbeScriptBase} from "./OutbeScriptBase.sol";

contract PredictAddresses is OutbeScriptBase {
    function run() public view {
        predictUpgradeableAddresses(deployer);
    }

    function predictUpgradeableAddresses(address deployer) internal view {
        console.log("=== Upgradeable Contracts (UUPS Proxy Pattern) ===");

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

        // Predict implementation addresses
        address predictedCraImpl = vm.computeCreate2Address(
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

        // Predict proxy addresses
        bytes memory craRegistryInitData = abi.encodeWithSignature("initialize(address)", deployer);
        bytes memory craProxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(predictedCraImpl, craRegistryInitData));
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
        console.log("- Salt bytes32:", vm.toString(craRegistryImplSaltBytes));
        console.log("- Predicted address:", predictedCraImpl);
        console.log("");

        console.log("CRA Registry Proxy (Main Contract):");
        console.log("- Salt bytes32:", vm.toString(craRegistryProxySaltBytes));
        console.log("- Predicted address:", predictedCraProxy);
        console.log("");

        console.log("Consumption Record Implementation:");
        console.log("- Salt bytes32:", vm.toString(crImplSaltBytes));
        console.log("- Predicted address:", predictedCrImpl);
        console.log("");

        console.log("Consumption Record Proxy (Main Contract):");
        console.log("- Salt bytes32:", vm.toString(crProxySaltBytes));
        console.log("- Predicted address:", predictedCrProxy);
        console.log("");

        console.log("Consumption Record Amendment Implementation:");
        console.log("- Salt bytes32:", vm.toString(crAImplSaltBytes));
        console.log("- Predicted address:", predictedCrAImpl);
        console.log("");

        console.log("Consumption Record Amendment Proxy (Main Contract):");
        console.log("- Salt bytes32:", vm.toString(crAProxySaltBytes));
        console.log("- Predicted address:", predictedCrAProxy);
        console.log("");

        console.log("Consumption Unit Implementation:");
        console.log("- Salt bytes32:", vm.toString(cuImplSaltBytes));
        console.log("- Predicted address:", predictedCuImpl);
        console.log("");

        console.log("Consumption Unit Proxy (Main Contract):");
        console.log("- Salt bytes32:", vm.toString(cuProxySaltBytes));
        console.log("- Predicted address:", predictedCuProxy);
        console.log("");

        console.log("Tribute Draft Implementation:");
        console.log("- Salt bytes32:", vm.toString(tdImplSaltBytes));
        console.log("- Predicted address:", predictedTdImpl);
        console.log("");

        console.log("Tribute Draft Proxy (Main Contract):");
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
        console.log(string.concat("export CRA_REGISTRY_ADDRESS=", vm.toString(predictedCraProxy)));
        console.log(string.concat("export CONSUMPTION_RECORD_ADDRESS=", vm.toString(predictedCrProxy)));
        console.log(string.concat("export CONSUMPTION_RECORD_AMENDMENT_ADDRESS=", vm.toString(predictedCrAProxy)));
        console.log(string.concat("export CONSUMPTION_UNIT_ADDRESS=", vm.toString(predictedCuProxy)));
        console.log(string.concat("export TRIBUTE_DRAFT_ADDRESS=", vm.toString(predictedTdProxy)));
        console.log(string.concat("export CRA_REGISTRY_IMPL=", vm.toString(predictedCraImpl)));
        console.log(string.concat("export CONSUMPTION_RECORD_IMPL=", vm.toString(predictedCrImpl)));
        console.log(string.concat("export CONSUMPTION_RECORD_AMENDMENT_IMPL=", vm.toString(predictedCrAImpl)));
        console.log(string.concat("export CONSUMPTION_UNIT_IMPL=", vm.toString(predictedCuImpl)));
        console.log(string.concat("export TRIBUTE_DRAFT_IMPL=", vm.toString(predictedTdImpl)));
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
