// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {ConsumptionRecordUpgradeable} from "src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {IConsumptionRecord} from "src/interfaces/IConsumptionRecord.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionRecordUpgradeableGetByOwnerTest is Test {
    MockCRARegistry private registry;
    ConsumptionRecordUpgradeable private cr;

    address private ownerA = address(0xA11CE);
    address private ownerB = address(0xB0B);

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy implementation and proxy, initialize via proxy constructor
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            ConsumptionRecordUpgradeable.initialize.selector,
            address(registry),
            address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        cr = ConsumptionRecordUpgradeable(address(proxy));

        // Make this test contract an active CRA so it can call submit()
        registry.setActive(address(this), true);
    }

    function _submit(uint256 id, address to, string[] memory keys, bytes32[] memory values) internal {
        cr.submit(id, to, keys, values);
    }

    function test_getConsumptionRecordsByOwner_fullRange() public {
        // Prepare: submit 5 records for ownerA (interleaved with 3 for ownerB)
        for (uint256 i = 0; i < 8; i++) {
            uint256 crId = uint256(keccak256(abi.encode("consumption-record", i))); // unique and valid
            address to = (i % 2 == 0) ? ownerA : ownerB; // A,B,A,B,A,B,A,B => A has 4, B has 4
            // adjust to get 5 for A and 3 for B: make last two go to A
            if (i >= 6) {
                to = ownerA; // i=6,7 go to A
            }
            _submit(crId, to, new string[](0), new bytes32[](0));
        }
        // Now ownerA should have 6 tokens? Let's compute:
        // i:0 A,1 B,2 A,3 B,4 A,5 B,6 A,7 A => A: 6 (0,2,4,6,7 plus?) Wait counts: indices 0,2,4,6,7 = 5; plus ???
        // Let's recompute precisely below using balanceOf.

        uint256 balanceA = cr.balanceOf(ownerA);
        assertGt(balanceA, 0, "ownerA must have tokens");

        // Request the full range for ownerA
        uint256 indexFrom = 0;
        uint256 indexTo = balanceA - 1;
        IConsumptionRecord.ConsumptionRecordEntity[] memory list = cr.getConsumptionRecordsByOwner(ownerA, indexFrom, indexTo);

        assertEq(list.length, balanceA, "length mismatch");
        // Verify entity fields are populated and owner matches
        for (uint256 i = 0; i < list.length; i++) {
            assertEq(list[i].owner, ownerA, "owner mismatch");
            assertEq(list[i].crId, cr.tokenOfOwnerByIndex(ownerA, i), "order mismatch");
            // submittedBy must be this test (msg.sender in submit)
            assertEq(list[i].submittedBy, address(this), "submittedBy mismatch");
        }
    }

    function test_getConsumptionRecordsByOwner_subRange() public {
        // Submit 5 records to ownerA
        for (uint256 i = 0; i < 5; i++) {
            _submit(uint256(keccak256(abi.encode("consumption-record", i))), ownerA, new string[](0), new bytes32[](0));
        }
        // Ask for subset [1..3]
        IConsumptionRecord.ConsumptionRecordEntity[] memory list = cr.getConsumptionRecordsByOwner(ownerA, 1, 3);
        assertEq(list.length, 3, "subset length");
        // Verify ids match enumeration indices 1..3
        for (uint256 i = 0; i < list.length; i++) {
            uint256 expectedId = cr.tokenOfOwnerByIndex(ownerA, i + 1);
            assertEq(list[i].crId, expectedId, "subset order");
        }
    }

    function test_getConsumptionRecordsByOwner_invalidRange_reverts() public {
        vm.expectRevert(bytes("Invalid request"));
        cr.getConsumptionRecordsByOwner(ownerA, 2, 1);
    }

    function test_getConsumptionRecordsByOwner_tooBigRange_reverts() public {
        // n = indexTo - indexFrom + 1; make it 51
        vm.expectRevert(bytes("Request too big"));
        cr.getConsumptionRecordsByOwner(ownerA, 0, 50);
    }

    function test_getConsumptionRecordsByOwner_outOfBounds_reverts() public {
        // Submit only 2 tokens to ownerB
        _submit(uint256(keccak256(abi.encode("consumption-record", 1000))), ownerB, new string[](0), new bytes32[](0));
        _submit(uint256(keccak256(abi.encode("consumption-record", 1001))) , ownerB, new string[](0), new bytes32[](0));

        // Request within max n<=50, but beyond owner's balance
        // balanceB is 2; index 2 is out of bounds (0-based)
        vm.expectRevert(bytes("ERC721Enumerable: owner index out of bounds"));
        cr.getConsumptionRecordsByOwner(ownerB, 0, 2);
    }

    function test_getConsumptionRecordsByOwner_returnsMetadata() public {
        string[] memory keys = new string[](2);
        keys[0] = "kWh";
        keys[1] = "meter";
        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(uint256(123));
        values[1] = keccak256(abi.encodePacked("M-42"));

        uint256 id = uint256(keccak256(abi.encode("consumption-record", 7777))) ;
        _submit(id, ownerA, keys, values);

        IConsumptionRecord.ConsumptionRecordEntity[] memory list = cr.getConsumptionRecordsByOwner(ownerA, 0, 0);
        assertEq(list.length, 1);
        assertEq(list[0].owner, ownerA);
        assertEq(list[0].crId, id);
        assertEq(list[0].metadataKeys.length, 2);
        assertEq(keccak256(bytes(list[0].metadataKeys[0])), keccak256(bytes("kWh")));
        assertEq(keccak256(bytes(list[0].metadataKeys[1])), keccak256(bytes("meter")));
        assertEq(list[0].metadataValues[0], bytes32(uint256(123)));
        assertEq(list[0].metadataValues[1], keccak256(abi.encodePacked("M-42")));
    }
}
