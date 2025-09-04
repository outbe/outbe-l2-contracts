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

        registry = new CRARegistry(owner);
        crContract = new ConsumptionRecord(address(registry), owner);

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
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        assertTrue(crContract.isExists(CR_HASH_1));

        IConsumptionRecord.CrRecord memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.submittedAt, block.timestamp);
        assertEq(record.owner, recordOwner1);
        assertEq(record.metadataKeys.length, 0);
        assertEq(record.metadataValues.length, 0);
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
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);


        // Test the complete record structure
        IConsumptionRecord.CrRecord memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.submittedAt, block.timestamp);
        assertEq(record.owner, recordOwner1);
        assertEq(record.metadataKeys.length, 2);
        assertEq(record.metadataValues.length, 2);
        assertEq(record.metadataKeys[0], "region");
        assertEq(record.metadataKeys[1], "processing_type");
        assertEq(record.metadataValues[0], "EU");
        assertEq(record.metadataValues[1], "standard");
    }

    function test_Submit_RevertWhen_NotActiveCRA() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(unauthorized);
        vm.expectRevert(IConsumptionRecord.CRANotActive.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_Submit_RevertWhen_SuspendedCRA() public {
        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);

        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
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

    function test_Submit_RevertWhen_AlreadyExists() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_Submit_RevertWhen_AlreadyExists_DifferentCRA() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        vm.prank(cra2);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_Submit_RevertWhen_KeyValueMismatch() public {
        string[] memory keys = new string[](2);
        string[] memory values = new string[](1);
        keys[0] = "key1";
        keys[1] = "key2";
        values[0] = "value1";

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.MetadataKeyValueMismatch.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_Submit_RevertWhen_EmptyMetadataKey() public {
        string[] memory keys = new string[](1);
        string[] memory values = new string[](1);
        keys[0] = "";
        values[0] = "value1";

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.EmptyMetadataKey.selector);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
    }

    function test_Multiple_CRs_Different_CRAs() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        vm.prank(cra2);
        crContract.submit(CR_HASH_2, recordOwner2, keys, values);

        assertTrue(crContract.isExists(CR_HASH_1));
        assertTrue(crContract.isExists(CR_HASH_2));

        IConsumptionRecord.CrRecord memory record1 = crContract.getRecord(CR_HASH_1);
        IConsumptionRecord.CrRecord memory record2 = crContract.getRecord(CR_HASH_2);

        assertEq(record1.submittedBy, cra1);
        assertEq(record2.submittedBy, cra2);
        assertEq(record1.owner, recordOwner1);
        assertEq(record2.owner, recordOwner2);
    }

    function test_SetCRARegistry() public {
        CRARegistry newRegistry = new CRARegistry(owner);

        crContract.setCraRegistry(address(newRegistry));
        assertEq(crContract.getCraRegistry(), address(newRegistry));
    }

    function test_SetCRARegistry_RevertWhen_NotOwner() public {
        CRARegistry newRegistry = new CRARegistry(owner);

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
        IConsumptionRecord.CrRecord memory record = crContract.getRecord(keccak256("nonexistent"));
        assertEq(record.submittedBy, address(0));
        assertEq(record.submittedAt, 0);
        assertEq(record.owner, address(0));
        assertEq(record.metadataKeys.length, 0);
        assertEq(record.metadataValues.length, 0);
    }


    function testFuzz_Submit_ValidHash(bytes32 crHash) public {
        vm.assume(crHash != bytes32(0));
        vm.assume(!crContract.isExists(crHash));

        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(crHash, recordOwner1, keys, values);

        assertTrue(crContract.isExists(crHash));

        IConsumptionRecord.CrRecord memory record = crContract.getRecord(crHash);
        assertEq(record.submittedBy, cra1);
        assertEq(record.submittedAt, block.timestamp);
        assertEq(record.owner, recordOwner1);
        assertEq(record.metadataKeys.length, 0);
        assertEq(record.metadataValues.length, 0);
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
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);


        // Test the complete record structure
        IConsumptionRecord.CrRecord memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.submittedAt, block.timestamp);
        assertEq(record.owner, recordOwner1);
        assertEq(record.metadataKeys.length, 1);
        assertEq(record.metadataValues.length, 1);
        assertEq(record.metadataKeys[0], key);
        assertEq(record.metadataValues[0], value);
    }

    function test_Submit_RevertWhen_InvalidOwner() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.InvalidOwner.selector);
        crContract.submit(CR_HASH_1, address(0), keys, values);
    }

    function test_GetRecordsByOwner_Empty() public view {
        bytes32[] memory records = crContract.getRecordsByOwner(recordOwner1);
        assertEq(records.length, 0);
    }

    function test_GetRecordsByOwner_SingleRecord() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);

        bytes32[] memory records = crContract.getRecordsByOwner(recordOwner1);
        assertEq(records.length, 1);
        assertEq(records[0], CR_HASH_1);

        // Check other owner has no records
        bytes32[] memory otherRecords = crContract.getRecordsByOwner(recordOwner2);
        assertEq(otherRecords.length, 0);
    }

    function test_GetRecordsByOwner_MultipleRecords() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);
        
        bytes32 crHash3 = keccak256("cr_hash_3");
        bytes32 crHash4 = keccak256("cr_hash_4");

        // Submit multiple records for same owner
        vm.startPrank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
        crContract.submit(CR_HASH_2, recordOwner1, keys, values);
        crContract.submit(crHash3, recordOwner1, keys, values);
        vm.stopPrank();

        // Submit one record for different owner
        vm.prank(cra2);
        crContract.submit(crHash4, recordOwner2, keys, values);

        // Check owner1 has 3 records
        bytes32[] memory owner1Records = crContract.getRecordsByOwner(recordOwner1);
        assertEq(owner1Records.length, 3);
        assertEq(owner1Records[0], CR_HASH_1);
        assertEq(owner1Records[1], CR_HASH_2);
        assertEq(owner1Records[2], crHash3);

        // Check owner2 has 1 record
        bytes32[] memory owner2Records = crContract.getRecordsByOwner(recordOwner2);
        assertEq(owner2Records.length, 1);
        assertEq(owner2Records[0], crHash4);
    }

    function test_GetRecordsByOwner_CrossCRASubmissions() public {
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        // Different CRAs submit for same owner
        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner1, keys, values);
        
        vm.prank(cra2);
        crContract.submit(CR_HASH_2, recordOwner1, keys, values);

        bytes32[] memory records = crContract.getRecordsByOwner(recordOwner1);
        assertEq(records.length, 2);
        assertEq(records[0], CR_HASH_1);
        assertEq(records[1], CR_HASH_2);

        // Verify the actual records have correct submitters
        IConsumptionRecord.CrRecord memory record1 = crContract.getRecord(CR_HASH_1);
        IConsumptionRecord.CrRecord memory record2 = crContract.getRecord(CR_HASH_2);
        
        assertEq(record1.submittedBy, cra1);
        assertEq(record2.submittedBy, cra2);
        assertEq(record1.owner, recordOwner1);
        assertEq(record2.owner, recordOwner1);
    }

    function testFuzz_GetRecordsByOwner(address recordOwner) public {
        vm.assume(recordOwner != address(0));
        
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        // Initially no records
        bytes32[] memory initialRecords = crContract.getRecordsByOwner(recordOwner);
        assertEq(initialRecords.length, 0);

        // Submit a record for the owner
        vm.prank(cra1);
        crContract.submit(CR_HASH_1, recordOwner, keys, values);

        // Should have one record
        bytes32[] memory finalRecords = crContract.getRecordsByOwner(recordOwner);
        assertEq(finalRecords.length, 1);
        assertEq(finalRecords[0], CR_HASH_1);
    }

    function test_SubmitBatch_Basic() public {
        bytes32[] memory crHashes = new bytes32[](2);
        address[] memory owners = new address[](2);
        string[][] memory keysArray = new string[][](2);
        string[][] memory valuesArray = new string[][](2);

        crHashes[0] = CR_HASH_1;
        crHashes[1] = CR_HASH_2;
        owners[0] = recordOwner1;
        owners[1] = recordOwner2;
        keysArray[0] = new string[](0);
        keysArray[1] = new string[](0);
        valuesArray[0] = new string[](0);
        valuesArray[1] = new string[](0);

        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_1, cra1, block.timestamp);
        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_2, cra1, block.timestamp);
        vm.expectEmit(true, true, false, true);
        emit BatchSubmitted(2, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        assertTrue(crContract.isExists(CR_HASH_1));
        assertTrue(crContract.isExists(CR_HASH_2));

        IConsumptionRecord.CrRecord memory record1 = crContract.getRecord(CR_HASH_1);
        IConsumptionRecord.CrRecord memory record2 = crContract.getRecord(CR_HASH_2);

        assertEq(record1.submittedBy, cra1);
        assertEq(record1.owner, recordOwner1);
        assertEq(record2.submittedBy, cra1);
        assertEq(record2.owner, recordOwner2);
    }

    function test_SubmitBatch_WithMetadata() public {
        bytes32[] memory crHashes = new bytes32[](1);
        address[] memory owners = new address[](1);
        string[][] memory keysArray = new string[][](1);
        string[][] memory valuesArray = new string[][](1);

        crHashes[0] = CR_HASH_1;
        owners[0] = recordOwner1;
        
        string[] memory keys = new string[](2);
        string[] memory values = new string[](2);
        keys[0] = "region";
        keys[1] = "type";
        values[0] = "EU";
        values[1] = "renewable";
        
        keysArray[0] = keys;
        valuesArray[0] = values;

        vm.expectEmit(true, false, false, true);
        emit MetadataAdded(CR_HASH_1, "region", "EU");
        vm.expectEmit(true, false, false, true);
        emit MetadataAdded(CR_HASH_1, "type", "renewable");
        vm.expectEmit(true, true, false, true);
        emit Submitted(CR_HASH_1, cra1, block.timestamp);
        vm.expectEmit(true, true, false, true);
        emit BatchSubmitted(1, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        IConsumptionRecord.CrRecord memory record = crContract.getRecord(CR_HASH_1);
        assertEq(record.metadataKeys.length, 2);
        assertEq(record.metadataKeys[0], "region");
        assertEq(record.metadataKeys[1], "type");
        assertEq(record.metadataValues[0], "EU");
        assertEq(record.metadataValues[1], "renewable");
    }

    function test_SubmitBatch_RevertWhen_EmptyBatch() public {
        bytes32[] memory crHashes = new bytes32[](0);
        address[] memory owners = new address[](0);
        string[][] memory keysArray = new string[][](0);
        string[][] memory valuesArray = new string[][](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.EmptyBatch.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);
    }

    function test_SubmitBatch_RevertWhen_BatchTooLarge() public {
        uint256 batchSize = 101; // Exceeds MAX_BATCH_SIZE of 100
        bytes32[] memory crHashes = new bytes32[](batchSize);
        address[] memory owners = new address[](batchSize);
        string[][] memory keysArray = new string[][](batchSize);
        string[][] memory valuesArray = new string[][](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            crHashes[i] = keccak256(abi.encodePacked("hash", i));
            owners[i] = recordOwner1;
            keysArray[i] = new string[](0);
            valuesArray[i] = new string[](0);
        }

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.BatchSizeTooLarge.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);
    }

    function test_SubmitBatch_RevertWhen_ArrayLengthMismatch() public {
        bytes32[] memory crHashes = new bytes32[](2);
        address[] memory owners = new address[](1); // Mismatch
        string[][] memory keysArray = new string[][](2);
        string[][] memory valuesArray = new string[][](2);

        crHashes[0] = CR_HASH_1;
        crHashes[1] = CR_HASH_2;
        owners[0] = recordOwner1;
        keysArray[0] = new string[](0);
        keysArray[1] = new string[](0);
        valuesArray[0] = new string[](0);
        valuesArray[1] = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.MetadataKeyValueMismatch.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);
    }

    function test_SubmitBatch_RevertWhen_DuplicateHash() public {
        bytes32[] memory crHashes = new bytes32[](2);
        address[] memory owners = new address[](2);
        string[][] memory keysArray = new string[][](2);
        string[][] memory valuesArray = new string[][](2);

        crHashes[0] = CR_HASH_1;
        crHashes[1] = CR_HASH_1; // Duplicate hash
        owners[0] = recordOwner1;
        owners[1] = recordOwner2;
        keysArray[0] = new string[](0);
        keysArray[1] = new string[](0);
        valuesArray[0] = new string[](0);
        valuesArray[1] = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        // Ensure no records were created
        assertFalse(crContract.isExists(CR_HASH_1));
    }

    function test_SubmitBatch_RevertWhen_InvalidHash() public {
        bytes32[] memory crHashes = new bytes32[](2);
        address[] memory owners = new address[](2);
        string[][] memory keysArray = new string[][](2);
        string[][] memory valuesArray = new string[][](2);

        crHashes[0] = CR_HASH_1;
        crHashes[1] = bytes32(0); // Invalid hash
        owners[0] = recordOwner1;
        owners[1] = recordOwner2;
        keysArray[0] = new string[](0);
        keysArray[1] = new string[](0);
        valuesArray[0] = new string[](0);
        valuesArray[1] = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.InvalidHash.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        // Ensure no records were created
        assertFalse(crContract.isExists(CR_HASH_1));
    }

    function test_SubmitBatch_RevertWhen_InvalidOwner() public {
        bytes32[] memory crHashes = new bytes32[](2);
        address[] memory owners = new address[](2);
        string[][] memory keysArray = new string[][](2);
        string[][] memory valuesArray = new string[][](2);

        crHashes[0] = CR_HASH_1;
        crHashes[1] = CR_HASH_2;
        owners[0] = recordOwner1;
        owners[1] = address(0); // Invalid owner
        keysArray[0] = new string[](0);
        keysArray[1] = new string[](0);
        valuesArray[0] = new string[](0);
        valuesArray[1] = new string[](0);

        vm.prank(cra1);
        vm.expectRevert(IConsumptionRecord.InvalidOwner.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        // Ensure no records were created
        assertFalse(crContract.isExists(CR_HASH_1));
        assertFalse(crContract.isExists(CR_HASH_2));
    }

    function test_SubmitBatch_RevertWhen_NotActiveCRA() public {
        bytes32[] memory crHashes = new bytes32[](1);
        address[] memory owners = new address[](1);
        string[][] memory keysArray = new string[][](1);
        string[][] memory valuesArray = new string[][](1);

        crHashes[0] = CR_HASH_1;
        owners[0] = recordOwner1;
        keysArray[0] = new string[](0);
        valuesArray[0] = new string[](0);

        vm.prank(unauthorized);
        vm.expectRevert(IConsumptionRecord.CRANotActive.selector);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);
    }

    function test_SubmitBatch_MaxSize() public {
        uint256 batchSize = 100; // Exactly MAX_BATCH_SIZE
        bytes32[] memory crHashes = new bytes32[](batchSize);
        address[] memory owners = new address[](batchSize);
        string[][] memory keysArray = new string[][](batchSize);
        string[][] memory valuesArray = new string[][](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            crHashes[i] = keccak256(abi.encodePacked("hash", i));
            owners[i] = recordOwner1;
            keysArray[i] = new string[](0);
            valuesArray[i] = new string[](0);
        }

        vm.expectEmit(true, true, false, true);
        emit BatchSubmitted(100, cra1, block.timestamp);

        vm.prank(cra1);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        // Verify all records were created
        for (uint256 i = 0; i < batchSize; i++) {
            assertTrue(crContract.isExists(crHashes[i]));
        }

        // Verify owner has all records
        bytes32[] memory ownerRecords = crContract.getRecordsByOwner(recordOwner1);
        assertEq(ownerRecords.length, batchSize);
    }

    function test_SubmitBatch_MixedOwners() public {
        bytes32[] memory crHashes = new bytes32[](4);
        address[] memory owners = new address[](4);
        string[][] memory keysArray = new string[][](4);
        string[][] memory valuesArray = new string[][](4);

        crHashes[0] = keccak256("hash1");
        crHashes[1] = keccak256("hash2");
        crHashes[2] = keccak256("hash3");
        crHashes[3] = keccak256("hash4");
        
        owners[0] = recordOwner1;
        owners[1] = recordOwner1;
        owners[2] = recordOwner2;
        owners[3] = recordOwner2;

        for (uint256 i = 0; i < 4; i++) {
            keysArray[i] = new string[](0);
            valuesArray[i] = new string[](0);
        }

        vm.prank(cra1);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        // Verify owner records
        bytes32[] memory owner1Records = crContract.getRecordsByOwner(recordOwner1);
        bytes32[] memory owner2Records = crContract.getRecordsByOwner(recordOwner2);
        
        assertEq(owner1Records.length, 2);
        assertEq(owner2Records.length, 2);
        
        assertEq(owner1Records[0], crHashes[0]);
        assertEq(owner1Records[1], crHashes[1]);
        assertEq(owner2Records[0], crHashes[2]);
        assertEq(owner2Records[1], crHashes[3]);
    }

    function testFuzz_SubmitBatch(uint8 batchSize) public {
        vm.assume(batchSize > 0 && batchSize <= 100);
        
        bytes32[] memory crHashes = new bytes32[](batchSize);
        address[] memory owners = new address[](batchSize);
        string[][] memory keysArray = new string[][](batchSize);
        string[][] memory valuesArray = new string[][](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            crHashes[i] = keccak256(abi.encodePacked("fuzz_hash", i));
            owners[i] = recordOwner1;
            keysArray[i] = new string[](0);
            valuesArray[i] = new string[](0);
        }

        vm.prank(cra1);
        crContract.submitBatch(crHashes, owners, keysArray, valuesArray);

        // Verify all records exist
        for (uint256 i = 0; i < batchSize; i++) {
            assertTrue(crContract.isExists(crHashes[i]));
        }

        // Verify owner has correct number of records
        bytes32[] memory ownerRecords = crContract.getRecordsByOwner(recordOwner1);
        assertEq(ownerRecords.length, batchSize);
    }
}
