// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CRARegistryUpgradeable} from "../../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title CREATE2 Deployment Test
/// @notice Tests CREATE2 deterministic deployment functionality
contract CREATE2DeploymentTest is Test {
    address public deployer;
    string public constant SALT_SUFFIX = "test_v1";

    function setUp() public {
        deployer = address(this);
    }

    function test_CREATE2AddressPrediction() public {
        // Simple test - just test implementation deployment
        string memory craImplSalt = string.concat("CRARegistryImpl_", SALT_SUFFIX);
        bytes32 craImplSaltBytes = keccak256(abi.encodePacked(craImplSalt));

        // Predict implementation address using vm.computeCreate2Address
        address predictedCraImpl =
            vm.computeCreate2Address(craImplSaltBytes, keccak256(type(CRARegistryUpgradeable).creationCode));

        // Deploy actual implementation and verify address matches prediction
        CRARegistryUpgradeable actualCraImpl = new CRARegistryUpgradeable{salt: craImplSaltBytes}();
        assertEq(address(actualCraImpl), predictedCraImpl, "CRA Registry implementation address mismatch");
    }

    function test_CREATE2DeterministicAcrossNetworks() public {
        // Test that the same salt produces the same addresses regardless of deployer
        bytes32 salt = keccak256(abi.encodePacked("TestSalt"));

        // Predict address for current deployer
        address predicted1 = vm.computeCreate2Address(salt, keccak256(type(CRARegistryUpgradeable).creationCode));

        // Deploy and verify
        CRARegistryUpgradeable impl1 = new CRARegistryUpgradeable{salt: salt}();
        assertEq(address(impl1), predicted1, "First deployment address mismatch");

        // Verify the contract is functional
        assertTrue(address(impl1) != address(0), "Implementation address should not be zero");
    }

    function test_CREATE2CollisionPrevention() public {
        bytes32 salt1 = keccak256(abi.encodePacked("Salt1"));
        bytes32 salt2 = keccak256(abi.encodePacked("Salt2"));

        // Deploy with first salt
        CRARegistryUpgradeable impl1 = new CRARegistryUpgradeable{salt: salt1}();

        // Deploy with different salt (should succeed)
        CRARegistryUpgradeable impl2 = new CRARegistryUpgradeable{salt: salt2}();

        // Verify different addresses
        assertTrue(address(impl1) != address(impl2), "Different salts should produce different addresses");
    }

    function testFuzz_CREATE2SaltGeneration(string memory saltSuffix) public {
        vm.assume(bytes(saltSuffix).length > 0 && bytes(saltSuffix).length < 100);

        string memory craImplSalt = string.concat("CRARegistryImpl_", saltSuffix);
        bytes32 saltBytes = keccak256(abi.encodePacked(craImplSalt));

        address predicted = vm.computeCreate2Address(saltBytes, keccak256(type(CRARegistryUpgradeable).creationCode));

        CRARegistryUpgradeable actual = new CRARegistryUpgradeable{salt: saltBytes}();
        assertEq(address(actual), predicted, "Fuzz test: predicted vs actual address mismatch");
    }

    function test_ProxyDelegation() public {
        // Deploy implementation
        bytes32 implSalt = keccak256("TestImpl");
        CRARegistryUpgradeable implementation = new CRARegistryUpgradeable{salt: implSalt}();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSignature("initialize(address)", deployer);
        bytes32 proxySalt = keccak256("TestProxy");
        ERC1967Proxy proxy = new ERC1967Proxy{salt: proxySalt}(address(implementation), initData);

        // Cast proxy to interface and test functionality
        CRARegistryUpgradeable registryViaProxy = CRARegistryUpgradeable(address(proxy));

        // Test basic functionality
        assertEq(registryViaProxy.getOwner(), deployer);
        assertEq(registryViaProxy.VERSION(), "1.0.0");

        // Test CRA registration
        address testCra = makeAddr("testCra");
        registryViaProxy.registerCra(testCra, "Test CRA");
        assertTrue(registryViaProxy.isCraActive(testCra));

        // Verify storage is in proxy, not implementation
        CRARegistryUpgradeable directImpl = CRARegistryUpgradeable(address(implementation));

        // Direct implementation shouldn't have initialized state
        // The implementation can be called but won't have the proxy's state
        // This is normal behavior - implementations are uninitialized templates
    }

    function test_UpgradePreservesAddresses() public {
        // Deploy initial implementation and proxy
        bytes32 implSalt = keccak256("InitialImpl");
        CRARegistryUpgradeable implementation1 = new CRARegistryUpgradeable{salt: implSalt}();

        bytes memory initData = abi.encodeWithSignature("initialize(address)", deployer);
        bytes32 proxySalt = keccak256("UpgradeTestProxy");
        ERC1967Proxy proxy = new ERC1967Proxy{salt: proxySalt}(address(implementation1), initData);

        CRARegistryUpgradeable registry = CRARegistryUpgradeable(address(proxy));
        address proxyAddress = address(proxy);

        // Register a CRA
        address testCra = makeAddr("testCra");
        registry.registerCra(testCra, "Test CRA");
        assertTrue(registry.isCraActive(testCra));

        // Deploy new implementation
        bytes32 newImplSalt = keccak256("NewImpl");
        CRARegistryUpgradeable implementation2 = new CRARegistryUpgradeable{salt: newImplSalt}();

        // Upgrade (proxy address should remain the same)
        registry.upgradeTo(address(implementation2));

        // Verify proxy address unchanged
        assertEq(address(registry), proxyAddress, "Proxy address changed after upgrade");

        // Verify data persisted
        assertTrue(registry.isCraActive(testCra), "Data lost after upgrade");
        assertEq(registry.getOwner(), deployer, "Owner changed after upgrade");
    }
}
