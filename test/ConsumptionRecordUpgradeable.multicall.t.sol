// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISoulBoundToken} from "../src/interfaces/ISoulBoundToken.sol";
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICRAAware} from "../src/interfaces/ICRAAware.sol";
import {IConsumptionRecord} from "../src/interfaces/IConsumptionRecord.sol";
import {MockCRARegistry} from "./helpers.t.sol";
import {Test} from "../lib/forge-std/src/Test.sol";

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
        return
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.submit.selector, uint256(crHash), owner_, keys, values);
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
        emit ISoulBoundToken.Minted(craActive, recordOwner, uint256(h1));
        vm.expectEmit(true, true, false, true);
        emit ISoulBoundToken.Minted(craActive, recordOwner, uint256(h2));

        vm.prank(craActive);
        bytes[] memory batch = new bytes[](2);
        batch[0] = c1;
        batch[1] = c2;
        cr.multicall(batch);

        // First entity
        IConsumptionRecord.ConsumptionRecordEntity memory e1 = cr.getTokenData(uint256(h1));
        assertEq(e1.submittedBy, craActive);
        assertEq(e1.submittedAt, ts);
        assertEq(e1.owner, recordOwner);
        assertEq(e1.metadataKeys.length, 1);
        assertEq(e1.metadataValues.length, 1);
        assertEq(e1.metadataKeys[0], "k1");
        assertEq(e1.metadataValues[0], bytes32(uint256(111)));

        // Second entity
        IConsumptionRecord.ConsumptionRecordEntity memory e2 = cr.getTokenData(uint256(h2));
        assertEq(e2.submittedBy, craActive);
        assertEq(e2.submittedAt, ts);
        assertEq(e2.owner, recordOwner);
        assertEq(e2.metadataKeys[0], "k2");
        assertEq(e2.metadataValues[0], bytes32(uint256(222)));

        // Owner index and total supply
        uint256 ownedCount = cr.balanceOf(recordOwner);
        assertEq(ownedCount, 2);
        assertEq(cr.totalSupply(), 2);
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
