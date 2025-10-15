// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConsumptionRecordUpgradeable} from "src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {IConsumptionRecord} from "src/interfaces/IConsumptionRecord.sol";
import {IConsumptionUnit} from "src/interfaces/IConsumptionUnit.sol";
import {ICRAAware} from "src/interfaces/ICRAAware.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionUnitUpgradeableSubmitTest is Test {
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

        // Seed one CR so that CU can reference it
        {
            string[] memory keys = new string[](1);
            bytes32[] memory vals = new bytes32[](1);
            keys[0] = "seed";
            vals[0] = bytes32(uint256(1));
            vm.prank(craActive);
            cr.submit(keccak256("cr-seed"), recordOwner, keys, vals);
        }

        // Deploy CU and initialize via ERC1967Proxy with CR address configured
        {
            ConsumptionUnitUpgradeable implCU = new ConsumptionUnitUpgradeable();
            bytes memory initCU = abi.encodeWithSelector(
                ConsumptionUnitUpgradeable.initialize.selector, address(registry), owner, address(cr)
            );
            ERC1967Proxy proxyCU = new ERC1967Proxy(address(implCU), initCU);
            cu = ConsumptionUnitUpgradeable(address(proxyCU));
        }
    }

    function _seedCR(bytes32 crHash) internal {
        string[] memory keys = new string[](1);
        bytes32[] memory vals = new bytes32[](1);
        keys[0] = "k";
        vals[0] = bytes32(uint256(123));
        vm.prank(craActive);
        cr.submit(crHash, recordOwner, keys, vals);
    }

    function test_submit_persists_full_entity_and_indexes_and_emits_event() public {
        // prepare CRs to link
        bytes32 crHash = keccak256("cr-ok");
        _seedCR(crHash);

        bytes32 cuHash = keccak256("cu-1");
        uint16 currency = 840; // USD
        uint32 wday = 20250923;
        uint64 baseAmt = 10;
        uint128 attoAmt = 5;
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = crHash;

        uint256 ts = 1_800_000_000;
        vm.warp(ts);

        vm.expectEmit(true, true, false, true);
        emit IConsumptionUnit.Submitted(cuHash, craActive, ts);

        vm.prank(craActive);
        cu.submit(cuHash, recordOwner, currency, wday, baseAmt, attoAmt, crHashes);

        // isExists
        assertTrue(cu.isExists(cuHash));

        // entity fields
        IConsumptionUnit.ConsumptionUnitEntity memory e = cu.getConsumptionUnit(cuHash);
        assertEq(e.consumptionUnitId, cuHash);
        assertEq(e.owner, recordOwner);
        assertEq(e.submittedBy, craActive);
        assertEq(e.submittedAt, ts);
        assertEq(e.settlementCurrency, currency);
        assertEq(e.worldwideDay, wday);
        assertEq(e.settlementAmountBase, baseAmt);
        assertEq(e.settlementAmountAtto, attoAmt);
        assertEq(e.crHashes.length, 1);
        assertEq(e.crHashes[0], crHash);

        // owner index
        bytes32[] memory owned = cu.getConsumptionUnitsByOwner(recordOwner);
        assertEq(owned.length, 1);
        assertEq(owned[0], cuHash);

        // totalSupply tracks count
        assertEq(cu.totalSupply(), 1);
    }

    function test_submit_reverts_on_zero_hash() public {
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-x");
        _seedCR(crHashes[0]);

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidHash.selector);
        cu.submit(bytes32(0), recordOwner, 978, 20250101, 1, 0, crHashes);
    }

    function test_submit_reverts_on_zero_owner() public {
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-y");
        _seedCR(crHashes[0]);

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidOwner.selector);
        cu.submit(keccak256("cu-x"), address(0), 978, 20250101, 1, 0, crHashes);
    }

    function test_submit_reverts_on_invalid_currency_zero() public {
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-curr");
        _seedCR(crHashes[0]);

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidSettlementCurrency.selector);
        cu.submit(keccak256("cu-curr"), recordOwner, 0, 20250101, 1, 0, crHashes);
    }

    function test_submit_reverts_on_invalid_amount_both_zero() public {
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-amt0");
        _seedCR(crHashes[0]);

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidAmount.selector);
        cu.submit(keccak256("cu-amt0"), recordOwner, 978, 20250101, 0, 0, crHashes);
    }

    function test_submit_reverts_on_invalid_amount_atto_ge_1e18() public {
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-amt1");
        _seedCR(crHashes[0]);

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidAmount.selector);
        cu.submit(keccak256("cu-amt1"), recordOwner, 978, 20250101, 0, uint128(1e18), crHashes);
    }

    function test_submit_reverts_on_empty_cr_hashes() public {
        bytes32[] memory crHashes = new bytes32[](0);

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidConsumptionRecords.selector);
        cu.submit(keccak256("cu-empty"), recordOwner, 978, 20250101, 1, 0, crHashes);
    }

    function test_submit_reverts_on_unknown_cr_hash() public {
        // don't seed this CR
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-unknown");

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidConsumptionRecords.selector);
        cu.submit(keccak256("cu-unknown"), recordOwner, 978, 20250101, 1, 0, crHashes);
    }

    function test_submit_reverts_on_duplicate_cr_hash_in_input_array() public {
        bytes32 h = keccak256("cr-dupe");
        _seedCR(h);
        bytes32[] memory crHashes = new bytes32[](2);
        crHashes[0] = h;
        crHashes[1] = h;

        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.ConsumptionRecordAlreadyExists.selector);
        cu.submit(keccak256("cu-dupe"), recordOwner, 978, 20250101, 1, 0, crHashes);
    }

    function test_submit_reverts_on_cr_hash_used_globally_before() public {
        bytes32 h = keccak256("cr-used");
        _seedCR(h);

        bytes32[] memory arr = new bytes32[](1);
        arr[0] = h;

        vm.startPrank(craActive);
        cu.submit(keccak256("cu-first"), recordOwner, 978, 20250101, 1, 0, arr);
        vm.expectRevert(IConsumptionUnit.ConsumptionRecordAlreadyExists.selector);
        cu.submit(keccak256("cu-second"), recordOwner, 978, 20250101, 2, 0, arr);
        vm.stopPrank();
    }

    function test_submit_reverts_on_duplicate_cu_hash() public {
        bytes32 h = keccak256("cr-dup-cu");
        _seedCR(h);
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = h;

        vm.startPrank(craActive);
        bytes32 cuHash = keccak256("cu-dup");
        cu.submit(cuHash, recordOwner, 978, 20250101, 1, 0, arr);
        vm.expectRevert(IConsumptionUnit.AlreadyExists.selector);
        cu.submit(cuHash, recordOwner, 978, 20250101, 1, 0, arr);
        vm.stopPrank();
    }

    function test_submit_reverts_for_inactive_or_unknown_CRA() public {
        bytes32 h = keccak256("cr-inact");
        _seedCR(h);
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = h;

        vm.prank(craInactive);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cu.submit(keccak256("cu-inact"), recordOwner, 978, 20250101, 1, 0, arr);

        address craUnknown = address(0xEefe);
        vm.prank(craUnknown);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cu.submit(keccak256("cu-unk"), recordOwner, 978, 20250101, 1, 0, arr);
    }
}
