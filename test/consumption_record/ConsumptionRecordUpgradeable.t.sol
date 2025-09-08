// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ConsumptionRecordUpgradeable} from "../../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {CRARegistryUpgradeable} from "../../src/cra_registry/CRARegistryUpgradeable.sol";
import {ICRARegistry} from "../../src/interfaces/ICRARegistry.sol";
import {IConsumptionRecord} from "../../src/interfaces/IConsumptionRecord.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ConsumptionRecordUpgradeableTest is Test {
    ConsumptionRecordUpgradeable public crContract;
    CRARegistryUpgradeable public registry;

    ConsumptionRecordUpgradeable public crImplementation;
    CRARegistryUpgradeable public registryImplementation;

    ERC1967Proxy public crProxy;
    ERC1967Proxy public registryProxy;

    address public owner;
    address public cra1;
    address public cra2;
    address public unauthorized;
    address public recordOwner1;
    address public recordOwner2;

    bytes32 public constant CR_HASH_1 = keccak256("cr_hash_1");
    bytes32 public constant CR_HASH_2 = keccak256("cr_hash_2");
    bytes32 public constant ZERO_HASH = bytes32(0);

    event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp);
    event MetadataAdded(bytes32 indexed crHash, string key, string value);
    event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);

    function setUp() public {
        owner = address(this);
        cra1 = makeAddr("cra1");
        cra2 = makeAddr("cra2");
        unauthorized = makeAddr("unauthorized");
        recordOwner1 = makeAddr("recordOwner1");
        recordOwner2 = makeAddr("recordOwner2");

        // Deploy CRA Registry
        registryImplementation = new CRARegistryUpgradeable();
        bytes memory registryInitData = abi.encodeWithSignature("initialize(address)", owner);
        registryProxy = new ERC1967Proxy(address(registryImplementation), registryInitData);
        registry = CRARegistryUpgradeable(address(registryProxy));

        // Deploy Consumption Record
        crImplementation = new ConsumptionRecordUpgradeable();
        bytes memory crInitData = abi.encodeWithSignature("initialize(address,address)", address(registry), owner);
        crProxy = new ERC1967Proxy(address(crImplementation), crInitData);
        crContract = ConsumptionRecordUpgradeable(address(crProxy));

        // Register CRAs
        registry.registerCra(cra1, "CRA One");
        registry.registerCra(cra2, "CRA Two");
    }

    function test_InitialState() public view {
        assertEq(crContract.getOwner(), owner);
        assertEq(crContract.getCraRegistry(), address(registry));
        assertFalse(crContract.isExists(CR_HASH_1));
        assertEq(crContract.VERSION(), "1.0.0");
        assertEq(crContract.MAX_BATCH_SIZE(), 100);
    }

    function test_Initialize_RevertWhen_ZeroRegistry() public {
        ConsumptionRecordUpgradeable newImpl = new ConsumptionRecordUpgradeable();

        bytes memory initData = abi.encodeWithSignature("initialize(address,address)", address(0), owner);

        vm.expectRevert("CRA Registry cannot be zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertWhen_ZeroOwner() public {
        ConsumptionRecordUpgradeable newImpl = new ConsumptionRecordUpgradeable();

        bytes memory initData = abi.encodeWithSignature("initialize(address,address)", address(registry), address(0));

        vm.expectRevert("Owner cannot be zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Submit_Basic() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_1, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        assertTrue(crContract.isExists(CR_HASH_1));

        IConsumptionRecord.ConsumptionRecordEntity memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.owner, recordOwner1);
        assertEq(record.submittedAt, block.timestamp);
        assertEq(record.metadataKeys.length, 0);
        assertEq(record.metadataValues.length, 0);

        bytes32[] memory ownerRecords = crContract.getRecordsByOwner(recordOwner1);
        assertEq(ownerRecords.length, 1);
        assertEq(ownerRecords[0], CR_HASH_1);
    }

    function test_Submit_WithMetadata() public {
        string[] memory keys = new string[](2);
        string[] memory values = new string[](2);
        keys[0] = "type";
        values[0] = "energy";
        keys[1] = "amount";
        values[1] = "100";

        vm.expectEmit(true, false, false, true);
        emit MetadataAdded(CR_HASH_1, "type", "energy");
        vm.expectEmit(true, false, false, true);
        emit MetadataAdded(CR_HASH_1, "amount", "100");
        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_1, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        IConsumptionRecord.ConsumptionRecordEntity memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.metadataKeys.length, 2);
        assertEq(record.metadataKeys[0], "type");
        assertEq(record.metadataKeys[1], "amount");
        assertEq(record.metadataValues[0], "energy");
        assertEq(record.metadataValues[1], "100");
    }

    function test_SubmitBatch() public {
        bytes32[] memory hashes = new bytes32[](2);
        address[] memory owners = new address[](2);
        string[][] memory keysArray = new string[][](2);
        string[][] memory valuesArray = new string[][](2);

        hashes[0] = CR_HASH_1;
        hashes[1] = CR_HASH_2;
        owners[0] = recordOwner1;
        owners[1] = recordOwner2;

        keysArray[0] = new string[](1);
        keysArray[0][0] = "type";
        valuesArray[0] = new string[](1);
        valuesArray[0][0] = "energy";

        keysArray[1] = new string[](0);
        valuesArray[1] = new string[](0);

        vm.expectEmit(true, true, false, true);
        emit BatchSubmitted(2, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submitBatch(hashes, owners, keysArray, valuesArray);

        assertTrue(crContract.isExists(CR_HASH_1));
        assertTrue(crContract.isExists(CR_HASH_2));

        bytes32[] memory owner1Records = crContract.getRecordsByOwner(recordOwner1);
        bytes32[] memory owner2Records = crContract.getRecordsByOwner(recordOwner2);
        assertEq(owner1Records.length, 1);
        assertEq(owner2Records.length, 1);
    }

    function test_Upgrade() public {
        // Submit a record to test data persistence
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "test";
        values[0] = "data";

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        assertTrue(crContract.isExists(CR_HASH_1));

        // Deploy new implementation
        ConsumptionRecordUpgradeable newImplementation = new ConsumptionRecordUpgradeable();

        // Perform upgrade
        crContract.upgradeTo(address(newImplementation));

        // Verify data persisted after upgrade
        assertTrue(crContract.isExists(CR_HASH_1));
        assertEq(crContract.getOwner(), owner);
        assertEq(crContract.getCraRegistry(), address(registry));

        IConsumptionRecord.ConsumptionRecordEntity memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.owner, recordOwner1);
        assertEq(record.metadataKeys[0], "test");
        assertEq(record.metadataValues[0], "data");

        bytes32[] memory ownerRecords = crContract.getRecordsByOwner(recordOwner1);
        assertEq(ownerRecords.length, 1);
        assertEq(ownerRecords[0], CR_HASH_1);
    }

    function test_Upgrade_RevertWhen_NotOwner() public {
        ConsumptionRecordUpgradeable newImplementation = new ConsumptionRecordUpgradeable();

        vm.prank(unauthorized);
        vm.expectRevert();
        crContract.upgradeTo(address(newImplementation));
    }

    function test_UpgradeAndCall() public {
        // Deploy new implementation
        ConsumptionRecordUpgradeable newImplementation = new ConsumptionRecordUpgradeable();

        // Prepare call data to update CRA registry after upgrade
        CRARegistryUpgradeable newRegistry = new CRARegistryUpgradeable();
        bytes memory registryInitData = abi.encodeWithSignature("initialize(address)", owner);
        ERC1967Proxy newRegistryProxy = new ERC1967Proxy(address(newRegistry), registryInitData);

        bytes memory data = abi.encodeWithSignature("setCraRegistry(address)", address(newRegistryProxy));

        // Perform upgrade and call
        crContract.upgradeToAndCall(address(newImplementation), data);

        // Verify the registry was updated
        assertEq(crContract.getCraRegistry(), address(newRegistryProxy));
        assertEq(crContract.getOwner(), owner);
    }

    function test_SetCRARegistry() public {
        CRARegistryUpgradeable newRegistry = new CRARegistryUpgradeable();
        bytes memory initData = abi.encodeWithSignature("initialize(address)", owner);
        ERC1967Proxy newRegistryProxy = new ERC1967Proxy(address(newRegistry), initData);

        crContract.setCraRegistry(address(newRegistryProxy));
        assertEq(crContract.getCraRegistry(), address(newRegistryProxy));
    }

    function test_SetCRARegistry_RevertWhen_NotOwner() public {
        CRARegistryUpgradeable newRegistry = new CRARegistryUpgradeable();
        bytes memory initData = abi.encodeWithSignature("initialize(address)", owner);
        ERC1967Proxy newRegistryProxy = new ERC1967Proxy(address(newRegistry), initData);

        vm.prank(unauthorized);
        vm.expectRevert();
        crContract.setCraRegistry(address(newRegistryProxy));
    }

    // Include other test functions from the original test file with minimal modifications...
    function test_Submit_RevertWhen_NotActiveCRA() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(unauthorized);
        vm.expectRevert(IConsumptionRecord.CRANotActive.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_Submit_RevertWhen_InvalidHash() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.InvalidHash.selector);
        crContract.submit(ZERO_HASH, recordOwner1, keys, values);
    }

    function test_Submit_RevertWhen_InvalidOwner() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.InvalidOwner.selector);
        crContract.submit(CR_HASH_1, address(0), keys, values);
    }

    function test_Submit_RevertWhen_AlreadyExists() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }
}
