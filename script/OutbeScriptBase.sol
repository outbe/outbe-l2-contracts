// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";

abstract contract OutbeScriptBase is Script {
    address internal deployer;
    uint256 internal deployerPrivateKey;
    string internal saltSuffix;

    function setUp() public {
        _setUpDeployer();
        _setUpSalt();

        console.log("=== Contracts Deployment Setup ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");
        console.log("Using salt suffix:", saltSuffix);
        console.log("");

        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");

        if (balance < 0.01 ether) {
            console.log("WARNING: Low balance, deployment may fail");
        }
        console.log("");
    }

    function _setUpDeployer() internal {
        // Load deployment parameters
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // Use default Anvil private key for testing
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("WARNING: Using default Anvil private key for testing");
        }

        deployer = vm.addr(deployerPrivateKey);
    }

    function _setUpSalt() internal {
        // Load or generate salt suffix for CREATE2 deterministic addresses
        saltSuffix = vm.envOr("SALT_SUFFIX", string("v1"));
        bool useTimestampSalt = vm.envOr("USE_TIMESTAMP_SALT", false);
        if (useTimestampSalt) {
            saltSuffix = vm.toString(block.timestamp);
            console.log("Using timestamp salt:", saltSuffix);
        }
    }

    /// @notice Get network name based on chain ID
    /// @return Network name string
    function getNetworkName() public view returns (string memory) {
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

    function generateSalt(string memory prefix) public view returns (bytes32) {
        string memory saltString = string.concat(prefix, saltSuffix);
        bytes32 salt = keccak256(abi.encodePacked(saltString));
        return salt;
    }
}
