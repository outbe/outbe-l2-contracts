// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ICRAAware} from "../src/interfaces/ICRAAware.sol";
import {IConsumptionRecord} from "../src/interfaces/IConsumptionRecord.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionRecordUpgradeableMulticallTest is Test {
    ConsumptionRecordUpgradeable cr;
    MockCRARegistry registry;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address craInactive = address(0xF00D);
    address recordOwner = address(0xBEEF);

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy implementation and initialize via ERC1967Proxy
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData =
                            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(registry), owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        cr = ConsumptionRecordUpgradeable(address(proxy));

        // Activate one CRA in registry
        registry.setActive(craActive, true);
    }

    function _singleKV(string memory k, uint256 v) internal pure returns (string[] memory, bytes32[] memory) {
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = k;
        values[0] = bytes32(uint256(v));
        return (keys, values);
    }

    function _encodeSubmit(bytes32 crHash, address owner_, string memory k, uint256 v)
    internal
    pure
    returns (bytes memory)
    {
        (string[] memory keys, bytes32[] memory values) = _singleKV(k, v);
        return abi.encodeWithSelector(ConsumptionRecordUpgradeable.submit.selector, crHash, owner_, keys, values);
    }

    function test_multicall_two_submits_persist_and_emit_and_count() public {
        bytes32 h1 = keccak256("rec-1");
        bytes32 h2 = keccak256("rec-2");
        bytes memory c1 = _encodeSubmit(h1, recordOwner, "k1", 111);
        bytes memory c2 = _encodeSubmit(h2, recordOwner, "k2", 222);

        uint256 ts = 1_800_000_000;
        vm.warp(ts);

        // Expect two Submitted events
        vm.expectEmit(true, true, false, true);
        emit IConsumptionRecord.Submitted(h1, craActive, ts);
        vm.expectEmit(true, true, false, true);
        emit IConsumptionRecord.Submitted(h2, craActive, ts);

        vm.prank(craActive);
        bytes[] memory batch = new bytes[](2);
        batch[0] = c1;
        batch[1] = c2;
        cr.multicall(batch);

        // First entity
        IConsumptionRecord.ConsumptionRecordEntity memory e1 = cr.getConsumptionRecord(h1);
        assertEq(e1.consumptionRecordId, h1);
        assertEq(e1.submittedBy, craActive);
        assertEq(e1.submittedAt, ts);
        assertEq(e1.owner, recordOwner);
        assertEq(e1.metadataKeys.length, 1);
        assertEq(e1.metadataValues.length, 1);
        assertEq(e1.metadataKeys[0], "k1");
        assertEq(e1.metadataValues[0], bytes32(uint256(111)));

        // Second entity
        IConsumptionRecord.ConsumptionRecordEntity memory e2 = cr.getConsumptionRecord(h2);
        assertEq(e2.consumptionRecordId, h2);
        assertEq(e2.submittedBy, craActive);
        assertEq(e2.submittedAt, ts);
        assertEq(e2.owner, recordOwner);
        assertEq(e2.metadataKeys[0], "k2");
        assertEq(e2.metadataValues[0], bytes32(uint256(222)));

        // Owner index and total supply
        bytes32[] memory owned = cr.getConsumptionRecordsByOwner(recordOwner);
        assertEq(owned.length, 2);
        assertEq(cr.totalSupply(), 2);
    }

    function test_multicall_reverts_on_empty_batch() public {
        bytes[] memory empty;
        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecord.EmptyBatch.selector);
        cr.multicall(empty);
    }

    function test_multicall_reverts_on_batch_too_large() public {
        // MAX_BATCH_SIZE is 100; create 101 calls
        uint256 n = 101;
        bytes[] memory batch = new bytes[](n);
        for (uint256 i = 0; i < n; i++) {
            batch[i] = _encodeSubmit(keccak256(abi.encode("rec", i)), recordOwner, "k", i);
        }
        vm.prank(craActive);
        vm.expectRevert(IConsumptionRecord.BatchSizeTooLarge.selector);
        cr.multicall(batch);
    }

    function test_multicall_reverts_when_not_active_cra() public {
        bytes32 h = keccak256("na");
        bytes[] memory batch = new bytes[](1);
        batch[0] = _encodeSubmit(h, recordOwner, "k", 1);

        vm.prank(craInactive);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cr.multicall(batch);
    }

    function test_multicall_reverts_when_paused() public {
        bytes32 h = keccak256("paused");
        bytes[] memory batch = new bytes[](1);
        batch[0] = _encodeSubmit(h, recordOwner, "k", 1);

        // owner pauses
        vm.prank(owner);
        cr.pause();

        vm.prank(craActive);
        vm.expectRevert("Pausable: paused");
        cr.multicall(batch);
    }
}
