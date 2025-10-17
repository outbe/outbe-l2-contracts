// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConsumptionRecordAmendmentUpgradeable} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {IConsumptionRecordAmendment} from "../src/interfaces/IConsumptionRecordAmendment.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionRecordAmendmentUpgradeableSubmitTest is Test {
    ConsumptionRecordAmendmentUpgradeable cra;
    MockCRARegistry registry;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address recordOwner = address(0xBEEF);

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy implementation and initialize via ERC1967Proxy
        ConsumptionRecordAmendmentUpgradeable impl = new ConsumptionRecordAmendmentUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            ConsumptionRecordAmendmentUpgradeable.initialize.selector, address(registry), owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        cra = ConsumptionRecordAmendmentUpgradeable(address(proxy));

        // mark the CRA as active in registry
        registry.setActive(craActive, true);
    }

    function _singleKV(string memory k, uint256 v) internal pure returns (string[] memory, bytes32[] memory) {
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = k;
        values[0] = bytes32(uint256(v));
        return (keys, values);
    }

    function test_submit_persists_full_entity_and_indexes_and_emits_event() public {
        bytes32 crAHash = keccak256("amend-1");
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 111);

        uint256 ts = 1_696_000_000;
        vm.warp(ts);

        // expect Submitted event
        vm.expectEmit(true, true, false, true);
        emit IConsumptionRecordAmendment.Submitted(crAHash, craActive, ts);

        vm.prank(craActive);
        cra.submit(crAHash, recordOwner, keys, values);

        // isExists
        assertTrue(cra.isExists(crAHash));

        // entity fields
        IConsumptionRecordAmendment.ConsumptionRecordAmendmentEntity memory e = cra.getConsumptionRecordAmendment(
            crAHash
        );
        assertEq(e.consumptionRecordAmendmentId, crAHash);
        assertEq(e.submittedBy, craActive);
        assertEq(e.submittedAt, ts);
        assertEq(e.owner, recordOwner);
        assertEq(e.metadataKeys.length, 1);
        assertEq(e.metadataValues.length, 1);
        assertEq(e.metadataKeys[0], "k1");
        assertEq(e.metadataValues[0], bytes32(uint256(111)));

        // owner index
        bytes32[] memory owned = cra.getConsumptionRecordAmendmentsByOwner(recordOwner);
        assertEq(owned.length, 1);
        assertEq(owned[0], crAHash);

        // totalSupply tracks count
        assertEq(cra.totalSupply(), 1);
    }

    function test_submit_reverts_on_zero_hash() public {
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 1);
        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecordAmendment.InvalidHash.selector);
        cra.submit(bytes32(0), recordOwner, keys, values);
    }

    function test_submit_reverts_on_zero_owner() public {
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 1);
        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecordAmendment.InvalidOwner.selector);
        cra.submit(keccak256("h"), address(0), keys, values);
    }

    function test_submit_reverts_on_mismatched_metadata_lengths() public {
        string[] memory keys = new string[](2);
        keys[0] = "k1";
        keys[1] = "k2";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));

        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecordAmendment.MetadataKeyValueMismatch.selector);
        cra.submit(keccak256("h2"), recordOwner, keys, values);
    }

    function test_submit_reverts_on_empty_metadata_key() public {
        string[] memory keys = new string[](1);
        keys[0] = "";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));

        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecordAmendment.EmptyMetadataKey.selector);
        cra.submit(keccak256("h3"), recordOwner, keys, values);
    }

    function test_submit_reverts_on_duplicate_hash() public {
        bytes32 crAHash = keccak256("dup");
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 5);

        vm.startPrank(craActive);
        cra.submit(crAHash, recordOwner, keys, values);
        vm.expectRevert(IConsumptionRecordAmendment.AlreadyExists.selector);
        cra.submit(crAHash, recordOwner, keys, values);
        vm.stopPrank();
    }
}
