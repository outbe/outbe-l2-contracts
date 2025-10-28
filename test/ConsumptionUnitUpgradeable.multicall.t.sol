// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConsumptionRecordUpgradeable} from "src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {ConsumptionRecordAmendmentUpgradeable} from "src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {IConsumptionUnit} from "src/interfaces/IConsumptionUnit.sol";
import {ICRAAware} from "src/interfaces/ICRAAware.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionUnitUpgradeableMulticallTest is Test {
    ConsumptionRecordUpgradeable cr;
    ConsumptionUnitUpgradeable cu;
    MockCRARegistry registry;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address craInactive = address(0xDEAD);
    address recordOwner = address(0xBEEF);

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy CR and initialize via ERC1967Proxy
        {
            ConsumptionRecordUpgradeable implCR = new ConsumptionRecordUpgradeable();
            bytes memory initCR =
                abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(registry), owner);
            ERC1967Proxy proxyCR = new ERC1967Proxy(address(implCR), initCR);
            cr = ConsumptionRecordUpgradeable(address(proxyCR));
        }

        // mark the CRA as active/inactive in registry
        registry.setActive(craActive, true);
        registry.setActive(craInactive, false);

        // Seed CRs that CU records will reference (must exist and be unique globally)
        _seedCR(uint256(keccak256("cr-A")));
        _seedCR(uint256(keccak256("cr-B")));

        // Deploy CRA (Consumption Record Amendment) and initialize via ERC1967Proxy
        ConsumptionRecordAmendmentUpgradeable cra;
        {
            ConsumptionRecordAmendmentUpgradeable implCRA = new ConsumptionRecordAmendmentUpgradeable();
            bytes memory initCRA = abi.encodeWithSelector(
                ConsumptionRecordAmendmentUpgradeable.initialize.selector, address(registry), owner
            );
            ERC1967Proxy proxyCRA = new ERC1967Proxy(address(implCRA), initCRA);
            cra = ConsumptionRecordAmendmentUpgradeable(address(proxyCRA));
        }

        // Deploy CU and initialize via ERC1967Proxy with CR and CRA addresses configured
        {
            ConsumptionUnitUpgradeable implCU = new ConsumptionUnitUpgradeable();
            bytes memory initCU = abi.encodeWithSelector(
                ConsumptionUnitUpgradeable.initialize.selector, address(registry), owner, address(cr), address(cra)
            );
            ERC1967Proxy proxyCU = new ERC1967Proxy(address(implCU), initCU);
            cu = ConsumptionUnitUpgradeable(address(proxyCU));
        }
    }

    function _seedCR(uint256 crHash) internal {
        string[] memory keys = new string[](1);
        bytes32[] memory vals = new bytes32[](1);
        keys[0] = "k";
        vals[0] = bytes32(uint256(123));
        vm.prank(craActive);
        cr.submit(crHash, recordOwner, keys, vals);
    }

    function _encodeSubmit(
        bytes32 cuHash,
        address _owner,
        uint16 currency,
        uint32 wday,
        uint64 baseAmt,
        uint128 attoAmt,
        bytes32[] memory crHashes
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ConsumptionUnitUpgradeable.submit.selector,
            cuHash,
            _owner,
            currency,
            wday,
            baseAmt,
            attoAmt,
            crHashes,
            new bytes32[](0)
        );
    }

    function test_multicall_two_submits_persist_and_emit_and_count() public {
        // Prepare two CU submits with distinct CR references
        bytes32 cuHash1 = keccak256("cu-1");
        bytes32 cuHash2 = keccak256("cu-2");

        uint16 currency = 978; // EUR
        uint32 wday = 20251231;
        uint64 baseAmt = 42;
        uint128 attoAmt = 17;

        bytes32[] memory crHashes1 = new bytes32[](1);
        crHashes1[0] = keccak256("cr-A");
        bytes32[] memory crHashes2 = new bytes32[](1);
        crHashes2[0] = keccak256("cr-B");

        bytes[] memory calls = new bytes[](2);
        calls[0] = _encodeSubmit(cuHash1, recordOwner, currency, wday, baseAmt, attoAmt, crHashes1);
        calls[1] = _encodeSubmit(cuHash2, recordOwner, currency, wday, baseAmt, attoAmt, crHashes2);

        uint256 ts = 1_900_000_000;
        vm.warp(ts);

        // Expect two Submitted events in order
        vm.expectEmit(true, true, false, true);
        emit IConsumptionUnit.Submitted(cuHash1, craActive, ts);
        vm.expectEmit(true, true, false, true);
        emit IConsumptionUnit.Submitted(cuHash2, craActive, ts);

        vm.prank(craActive);
        cu.multicall(calls);

        // Verify persistence for both
        assertTrue(cu.isExists(cuHash1));
        assertTrue(cu.isExists(cuHash2));

        IConsumptionUnit.ConsumptionUnitEntity memory e1 = cu.getConsumptionUnit(cuHash1);
        IConsumptionUnit.ConsumptionUnitEntity memory e2 = cu.getConsumptionUnit(cuHash2);

        assertEq(e1.submittedBy, craActive);
        assertEq(e2.submittedBy, craActive);
        assertEq(e1.submittedAt, ts);
        assertEq(e2.submittedAt, ts);
        assertEq(e1.owner, recordOwner);
        assertEq(e2.owner, recordOwner);
        assertEq(e1.crHashes.length, 1);
        assertEq(e2.crHashes.length, 1);
        assertEq(e1.crHashes[0], crHashes1[0]);
        assertEq(e2.crHashes[0], crHashes2[0]);

        // Owner index contains both
        bytes32[] memory owned = cu.getConsumptionUnitsByOwner(recordOwner);
        assertEq(owned.length, 2);
        assertEq(owned[0], cuHash1);
        assertEq(owned[1], cuHash2);

        // totalSupply increments by 2
        assertEq(cu.totalSupply(), 2);
    }

    function test_multicall_reverts_on_empty_batch() public {
        bytes[] memory calls = new bytes[](0);
        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.EmptyBatch.selector);
        cu.multicall(calls);
    }

    function test_multicall_reverts_on_batch_too_large() public {
        // Prepare MAX_BATCH_SIZE + 1 calls (101)
        uint256 n = 101;
        bytes[] memory calls = new bytes[](n);
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-A");
        for (uint256 i = 0; i < n; i++) {
            // Use different cu hashes and fresh CRs for uniqueness; seed on the fly
            bytes32 cuHash = keccak256(abi.encodePacked("cu-", i));
            bytes32 crh = keccak256(abi.encodePacked("cr-X-", i));
            _seedCR(uint256(crh));
            bytes32[] memory arr = new bytes32[](1);
            arr[0] = crh;
            calls[i] = _encodeSubmit(cuHash, recordOwner, 978, 20251231, 1, 0, arr);
        }
        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.BatchSizeTooLarge.selector);
        cu.multicall(calls);
    }

    function test_multicall_reverts_when_not_active_cra() public {
        // one valid call
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = keccak256("cr-A");
        bytes[] memory calls = new bytes[](1);
        calls[0] = _encodeSubmit(keccak256("cu-x"), recordOwner, 840, 20250101, 1, 0, arr);

        vm.prank(craInactive);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cu.multicall(calls);
    }

    function test_multicall_reverts_when_paused() public {
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = keccak256("cr-A");
        bytes[] memory calls = new bytes[](1);
        calls[0] = _encodeSubmit(keccak256("cu-y"), recordOwner, 840, 20250101, 1, 0, arr);

        vm.prank(owner);
        cu.pause();

        vm.prank(craActive);
        vm.expectRevert(bytes("Pausable: paused"));
        cu.multicall(calls);
    }
}
