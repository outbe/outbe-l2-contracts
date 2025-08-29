// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ConsumptionRecord} from "../../src/consumption_record/ConsumptionRecord.sol";
import {CRARegistry} from "../../src/cra_registry/CRARegistry.sol";
import {ICRARegistry} from "../../src/interfaces/ICRARegistry.sol";
import {IConsumptionRecord} from "../../src/interfaces/IConsumptionRecord.sol";

contract ConsumptionRecordTest is Test {
    ConsumptionRecord public crContract;
    CRARegistry public registry;
    address public owner;
    address public cra1;
    address public cra2;
    address public unauthorized;

    bytes32 public constant CR_HASH_1 = keccak256("cr_hash_1");
    bytes32 public constant CR_HASH_2 = keccak256("cr_hash_2");
    bytes32 public constant ZERO_HASH = bytes32(0);

    event Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp);
    event MetadataAdded(bytes32 indexed crHash, string key, string value);

    function setUp() public {
        owner = address(this);
        cra1 = makeAddr("cra1");
        cra2 = makeAddr("cra2");
        unauthorized = makeAddr("unauthorized");

        registry = new CRARegistry();
        crContract = new ConsumptionRecord(address(registry));

        registry.registerCra(cra1, "CRA One");
        registry.registerCra(cra2, "CRA Two");
    }

    function test_InitialState() public view {
        assertEq(crContract.getOwner(), owner);
        assertEq(crContract.getCraRegistry(), address(registry));
        assertFalse(crContract.isExists(CR_HASH_1));
    }

    function test_Submit_Basic() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_1, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, keys, values);

        assertTrue(crContract.isExists(CR_HASH_1));

        IConsumptionRecord.CrRecord memory record = crContract.getDetails(CR_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.submittedAt, block.timestamp);
    }

    function test_Submit_WithMetadata() public {
        string[] memory keys = new string[](2);
        string[] memory values = new string[](2);
        keys[0] = "region";
        keys[1] = "processing_type";
        values[0] = "EU";
        values[1] = "standard";

        vm.expectEmit(true, false, false, true);
        emit MetadataAdded(CR_HASH_1, "region", "EU");
        vm.expectEmit(true, false, false, true);
        emit MetadataAdded(CR_HASH_1, "processing_type", "standard");
        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_1, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, keys, values);

        assertEq(crContract.getMetadata(CR_HASH_1, "region"), "EU");
        assertEq(crContract.getMetadata(CR_HASH_1, "processing_type"), "standard");

        string[] memory storedKeys = crContract.getMetadataKeys(CR_HASH_1);
        assertEq(storedKeys.length, 2);
        assertEq(storedKeys[0], "region");
        assertEq(storedKeys[1], "processing_type");
    }

    function test_Submit_RevertWhen_NotActiveCRA() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(unauthorized);
        vm.expectRevert(IConsumptionRecord.CRANotActive.selector);
        crContract.submit(CR_HASH_1, keys, values);
    }

    function test_Submit_RevertWhen_SuspendedCRA() public {
        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);

        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.CRANotActive.selector);
        crContract.submit(CR_HASH_1, keys, values);
    }

    function test_Submit_RevertWhen_InvalidHash() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.InvalidHash.selector);
        crContract.submit(ZERO_HASH, keys, values);
    }

    function test_Submit_RevertWhen_AlreadyExists() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, keys, values);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        crContract.submit(CR_HASH_1, keys, values);
    }

    function test_Submit_RevertWhen_AlreadyExists_DifferentCRA() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, keys, values);

        vm.prank(cra2);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        crContract.submit(CR_HASH_1, keys, values);
    }

    function test_Submit_RevertWhen_KeyValueMismatch() public {
        string[] memory keys = new string[](2);
        string[] memory values = new string[](1);
        keys[0] = "key1";
        keys[1] = "key2";
        values[0] = "value1";

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.MetadataKeyValueMismatch.selector);
        crContract.submit(CR_HASH_1, keys, values);
    }

    function test_Submit_RevertWhen_EmptyMetadataKey() public {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "";
        values[0] = "value1";

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.EmptyMetadataKey.selector);
        crContract.submit(CR_HASH_1, keys, values);
    }

    function test_Multiple_CRs_Different_CRAs() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, keys, values);

        vm.prank(cra2);
        crContract.submit(CR_HASH_2, keys, values);

        assertTrue(crContract.isExists(CR_HASH_1));
        assertTrue(crContract.isExists(CR_HASH_2));

        IConsumptionRecord.CrRecord memory record1 = crContract.getDetails(CR_HASH_1);
        IConsumptionRecord.CrRecord memory record2 = crContract.getDetails(CR_HASH_2);

        assertEq(record1.submittedBy, cra1);
        assertEq(record2.submittedBy, cra2);
    }

    function test_SetCRARegistry() public {
        CRARegistry newRegistry = new CRARegistry();

        crContract.setCraRegistry(address(newRegistry));
        assertEq(crContract.getCraRegistry(), address(newRegistry));
    }

    function test_SetCRARegistry_RevertWhen_NotOwner() public {
        CRARegistry newRegistry = new CRARegistry();

        vm.prank(unauthorized);
        vm.expectRevert(IConsumptionRecord.CRANotActive.selector);
        crContract.setCraRegistry(address(newRegistry));
    }

    function test_OwnershipCheck() public view {
        assertEq(crContract.getOwner(), owner);
    }

    function test_CheckIsExists_NonExistent() public view {
        assertFalse(crContract.isExists(CR_HASH_1));
        assertFalse(crContract.isExists(keccak256("nonexistent")));
    }

    function test_GetDetails_NonExistent() public view {
        IConsumptionRecord.CrRecord memory record = crContract.getDetails(keccak256("nonexistent"));
        assertEq(record.submittedBy, address(0));
        assertEq(record.submittedAt, 0);
    }

    function test_getMetadata_NonExistent() public view {
        string memory value = crContract.getMetadata(keccak256("nonexistent"), "key");
        assertEq(bytes(value).length, 0);
    }

    function testFuzz_Submit_ValidHash(bytes32 crHash) public {
        vm.assume(crHash != bytes32(0));
        vm.assume(!crContract.isExists(crHash));

        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(crHash, keys, values);

        assertTrue(crContract.isExists(crHash));

        IConsumptionRecord.CrRecord memory record = crContract.getDetails(crHash);
        assertEq(record.submittedBy, cra1);
        assertEq(record.submittedAt, block.timestamp);
    }

    function testFuzz_Submit_WithMetadata(string memory key, string memory value) public {
        vm.assume(bytes(key).length > 0);
        vm.assume(bytes(key).length < 1000);
        vm.assume(bytes(value).length < 1000);

        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = key;
        values[0] = value;

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, keys, values);

        assertEq(crContract.getMetadata(CR_HASH_1, key), value);

        string[] memory storedKeys = crContract.getMetadataKeys(CR_HASH_1);
        assertEq(storedKeys.length, 1);
        assertEq(storedKeys[0], key);
    }
}
