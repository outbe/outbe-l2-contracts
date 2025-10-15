// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {IConsumptionRecord} from "../src/interfaces/IConsumptionRecord.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionRecordUpgradeableSubmitTest is Test {
    ConsumptionRecordUpgradeable cr;
    MockCRARegistry registry;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address recordOwner = address(0xBEEF);

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy implementation and initialize via ERC1967Proxy
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(registry), owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        cr = ConsumptionRecordUpgradeable(address(proxy));

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
        bytes32 crHash = keccak256("rec-1");
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 111);

        uint256 ts = 1_696_000_000;
        vm.warp(ts);

        // expect Submitted event
        vm.expectEmit(true, true, false, true);
        emit IConsumptionRecord.Submitted(crHash, craActive, ts);

        vm.prank(craActive);
        cr.submit(crHash, recordOwner, keys, values);

        // isExists
        assertTrue(cr.isExists(crHash));

        // entity fields
        IConsumptionRecord.ConsumptionRecordEntity memory e = cr.getConsumptionRecord(crHash);
        assertEq(e.consumptionRecordId, crHash);
        assertEq(e.submittedBy, craActive);
        assertEq(e.submittedAt, ts);
        assertEq(e.owner, recordOwner);
        assertEq(e.metadataKeys.length, 1);
        assertEq(e.metadataValues.length, 1);
        assertEq(e.metadataKeys[0], "k1");
        assertEq(e.metadataValues[0], bytes32(uint256(111)));

        // owner index
        bytes32[] memory owned = cr.getConsumptionRecordsByOwner(recordOwner);
        assertEq(owned.length, 1);
        assertEq(owned[0], crHash);

        // totalSupply tracks count
        assertEq(cr.totalSupply(), 1);
    }

    function test_submit_reverts_on_zero_hash() public {
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 1);
        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecord.InvalidHash.selector);
        cr.submit(bytes32(0), recordOwner, keys, values);
    }

    function test_submit_reverts_on_zero_owner() public {
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 1);
        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecord.InvalidOwner.selector);
        cr.submit(keccak256("h"), address(0), keys, values);
    }

    function test_submit_reverts_on_mismatched_metadata_lengths() public {
        string[] memory keys = new string[](2);
        keys[0] = "k1";
        keys[1] = "k2";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));

        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecord.MetadataKeyValueMismatch.selector);
        cr.submit(keccak256("h2"), recordOwner, keys, values);
    }

    function test_submit_reverts_on_empty_metadata_key() public {
        string[] memory keys = new string[](1);
        keys[0] = "";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));

        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecord.EmptyMetadataKey.selector);
        cr.submit(keccak256("h3"), recordOwner, keys, values);
    }

    function test_submit_reverts_on_duplicate_hash() public {
        bytes32 crHash = keccak256("dup");
        (string[] memory keys, bytes32[] memory values) = _singleKV("k1", 5);

        vm.startPrank(craActive);
        cr.submit(crHash, recordOwner, keys, values);
        vm.expectRevert(IConsumptionRecord.AlreadyExists.selector);
        cr.submit(crHash, recordOwner, keys, values);
        vm.stopPrank();
    }
}
