// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CRARegistry} from "../src/cra_registry/CRARegistry.sol";
import {ConsumptionRecord} from "../src/consumption_record/ConsumptionRecord.sol";

contract PredictAddresses is Script {
    function run() public view {
        address deployer = vm.addr(vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)));
        
        console.log("=== CREATE2 Address Predictions ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        // Predict CRARegistry address
        bytes32 registrySalt = keccak256("CRARegistry_v1");
        bytes memory registryBytecode = type(CRARegistry).creationCode;
        address predictedRegistry = computeCreate2Address(registrySalt, keccak256(registryBytecode), deployer);
        
        console.log("CRA Registry:");
        console.log("- Salt:", vm.toString(registrySalt));
        console.log("- Predicted address:", predictedRegistry);
        console.log("");
        
        // Predict ConsumptionRecord address
        bytes32 recordSalt = keccak256("ConsumptionRecord_v1");
        bytes memory recordBytecode = abi.encodePacked(
            type(ConsumptionRecord).creationCode,
            abi.encode(predictedRegistry)
        );
        address predictedRecord = computeCreate2Address(recordSalt, keccak256(recordBytecode), deployer);
        
        console.log("Consumption Record:");
        console.log("- Salt:", vm.toString(recordSalt));
        console.log("- Predicted address:", predictedRecord);
        console.log("");
        
        console.log("Environment variables:");
        console.log("export CRA_REGISTRY_ADDRESS=", predictedRegistry);
        console.log("export CONSUMPTION_RECORD_ADDRESS=", predictedRecord);
    }
    
    function computeCreate2Address(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure override returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            bytecodeHash
        )))));
    }
}