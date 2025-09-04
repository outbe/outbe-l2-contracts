// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CRARegistryUpgradeable} from "../../src/cra_registry/CRARegistryUpgradeable.sol";
import {ConsumptionRecordUpgradeable} from "../../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title UpgradeWorkflow Test
/// @notice Tests the complete upgrade workflow for both contracts
contract UpgradeWorkflowTest is Test {
    CRARegistryUpgradeable public craRegistry;
    ConsumptionRecordUpgradeable public consumptionRecord;

    address public craRegistryImpl;
    address public consumptionRecordImpl;

    address public owner;
    address public cra1;
    address public recordOwner1;

    bytes32 public constant CR_HASH_1 = keccak256("cr_hash_1");

    event Upgraded(address indexed implementation);

    function setUp() public {
        owner = address(this);
        cra1 = makeAddr("cra1");
        recordOwner1 = makeAddr("recordOwner1");

        // Deploy initial implementations
        craRegistryImpl = address(new CRARegistryUpgradeable());
        consumptionRecordImpl = address(new ConsumptionRecordUpgradeable());

        // Deploy proxies
        bytes memory craInitData = abi.encodeWithSignature("initialize(address)", owner);
        ERC1967Proxy craProxy = new ERC1967Proxy(craRegistryImpl, craInitData);
        craRegistry = CRARegistryUpgradeable(address(craProxy));

        bytes memory crInitData = abi.encodeWithSignature("initialize(address,address)", address(craRegistry), owner);
        ERC1967Proxy crProxy = new ERC1967Proxy(consumptionRecordImpl, crInitData);
        consumptionRecord = ConsumptionRecordUpgradeable(address(crProxy));

        // Setup initial state
        craRegistry.registerCra(cra1, "Test CRA");

        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "type";
        values[0] = "energy";

        vm.prank(cra1);
        consumptionRecord.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_FullUpgradeWorkflow() public {
        // Verify initial state
        assertEq(craRegistry.VERSION(), "1.0.0");
        assertEq(consumptionRecord.VERSION(), "1.0.0");
        assertTrue(craRegistry.isCraActive(cra1));
        assertTrue(consumptionRecord.isExists(CR_HASH_1));

        // Store proxy addresses (these should remain unchanged)
        address craProxyAddr = address(craRegistry);
        address crProxyAddr = address(consumptionRecord);

        // Step 1: Deploy new implementations
        address newCraImpl = address(new CRARegistryUpgradeable());
        address newCrImpl = address(new ConsumptionRecordUpgradeable());

        // Step 2: Upgrade CRA Registry
        vm.expectEmit(true, false, false, false);
        emit Upgraded(newCraImpl);
        craRegistry.upgradeTo(newCraImpl);

        // Step 3: Upgrade Consumption Record
        vm.expectEmit(true, false, false, false);
        emit Upgraded(newCrImpl);
        consumptionRecord.upgradeTo(newCrImpl);

        // Step 4: Verify proxy addresses unchanged
        assertEq(address(craRegistry), craProxyAddr);
        assertEq(address(consumptionRecord), crProxyAddr);

        // Step 5: Verify data persistence
        assertTrue(craRegistry.isCraActive(cra1));
        assertTrue(consumptionRecord.isExists(CR_HASH_1));

        address[] memory allCras = craRegistry.getAllCras();
        assertEq(allCras.length, 1);
        assertEq(allCras[0], cra1);

        bytes32[] memory ownerRecords = consumptionRecord.getRecordsByOwner(recordOwner1);
        assertEq(ownerRecords.length, 1);
        assertEq(ownerRecords[0], CR_HASH_1);

        // Step 6: Verify new functionality still works
        address cra2 = makeAddr("cra2");
        craRegistry.registerCra(cra2, "New CRA");
        assertTrue(craRegistry.isCraActive(cra2));

        bytes32 newHash = keccak256("new_record");
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra2);
        consumptionRecord.submit(newHash, recordOwner1, keys, values);
        assertTrue(consumptionRecord.isExists(newHash));
    }

    function test_UpgradeWithDataMigration() public {
        // Record pre-upgrade state
        address[] memory preCras = craRegistry.getAllCras();
        bytes32[] memory preRecords = consumptionRecord.getRecordsByOwner(recordOwner1);

        // Deploy new implementation
        address newImpl = address(new CRARegistryUpgradeable());

        // Upgrade with a data migration call
        bytes memory migrationCall =
            abi.encodeWithSignature("registerCra(address,string)", makeAddr("migrationCra"), "Migration CRA");

        craRegistry.upgradeToAndCall(newImpl, migrationCall);

        // Verify old data persisted
        address[] memory postCras = craRegistry.getAllCras();
        assertEq(postCras.length, preCras.length + 1);

        // Verify migration was executed
        assertTrue(craRegistry.isCraActive(makeAddr("migrationCra")));
    }

    function test_UpgradeRevertWhen_UnauthorizedCaller() public {
        address newImpl = address(new CRARegistryUpgradeable());
        address unauthorized = makeAddr("unauthorized");

        vm.prank(unauthorized);
        vm.expectRevert();
        craRegistry.upgradeTo(newImpl);

        vm.prank(unauthorized);
        vm.expectRevert();
        consumptionRecord.upgradeTo(newImpl);
    }

    function test_StorageLayoutConsistency() public {
        // Register multiple CRAs and records
        address[] memory testCras = new address[](5);
        bytes32[] memory testHashes = new bytes32[](5);

        for (uint256 i = 0; i < 5; i++) {
            testCras[i] = makeAddr(string(abi.encodePacked("cra", i)));
            testHashes[i] = keccak256(abi.encodePacked("hash", i));

            craRegistry.registerCra(testCras[i], string(abi.encodePacked("CRA ", i)));

            string[] memory keys = new string[](1);
            string[] memory values = new string[](1);
            keys[0] = "test";
            values[0] = string(abi.encodePacked("value", i));

            vm.prank(testCras[i]);
            consumptionRecord.submit(testHashes[i], recordOwner1, keys, values);
        }

        // Store state before upgrade
        uint256 preUpgradeCraCount = craRegistry.getAllCras().length;
        uint256 preUpgradeRecordCount = consumptionRecord.getRecordsByOwner(recordOwner1).length;

        // Upgrade both contracts
        address newCraImpl = address(new CRARegistryUpgradeable());
        address newCrImpl = address(new ConsumptionRecordUpgradeable());

        craRegistry.upgradeTo(newCraImpl);
        consumptionRecord.upgradeTo(newCrImpl);

        // Verify storage layout consistency
        assertEq(craRegistry.getAllCras().length, preUpgradeCraCount);
        assertEq(consumptionRecord.getRecordsByOwner(recordOwner1).length, preUpgradeRecordCount);

        // Verify all data accessible
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(craRegistry.isCraActive(testCras[i]));
            assertTrue(consumptionRecord.isExists(testHashes[i]));
        }
    }

    function test_ProxyAdminFunctionality() public {
        // Test that proxy admin functions work correctly
        address newImpl = address(new CRARegistryUpgradeable());

        // Get implementation before upgrade
        bytes32 IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address oldImpl = address(uint160(uint256(vm.load(address(craRegistry), IMPLEMENTATION_SLOT))));
        assertEq(oldImpl, craRegistryImpl);

        // Upgrade
        craRegistry.upgradeTo(newImpl);

        // Verify implementation changed
        address currentImpl = address(uint160(uint256(vm.load(address(craRegistry), IMPLEMENTATION_SLOT))));
        assertEq(currentImpl, newImpl);
        assertNotEq(currentImpl, oldImpl);
    }
}
