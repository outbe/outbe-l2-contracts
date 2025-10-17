// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {
    ConsumptionRecordAmendmentUpgradeable
} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {TributeDraftUpgradeable} from "../src/tribute_draft/TributeDraftUpgradeable.sol";
import {ITributeDraft} from "../src/interfaces/ITributeDraft.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract TributeDraftUpgradeableSubmitTest is Test {
    MockCRARegistry registry;

    ConsumptionRecordUpgradeable cr;
    ConsumptionUnitUpgradeable cu;
    TributeDraftUpgradeable td;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address recordOwner = address(0xBEEF);
    address other = address(0xD00D);

    uint16 currency = 978; // EUR
    uint32 worldwideDay = 20250923;

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy CR behind proxy
        ConsumptionRecordUpgradeable crImpl = new ConsumptionRecordUpgradeable();
        bytes memory crInit =
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(registry), owner);
        ERC1967Proxy crProxy = new ERC1967Proxy(address(crImpl), crInit);
        cr = ConsumptionRecordUpgradeable(address(crProxy));

        // Deploy CRA (Amendment) behind proxy
        ConsumptionRecordAmendmentUpgradeable craImpl = new ConsumptionRecordAmendmentUpgradeable();
        bytes memory craInit =
            abi.encodeWithSelector(ConsumptionRecordAmendmentUpgradeable.initialize.selector, address(registry), owner);
        ERC1967Proxy craProxy = new ERC1967Proxy(address(craImpl), craInit);
        ConsumptionRecordAmendmentUpgradeable cra = ConsumptionRecordAmendmentUpgradeable(address(craProxy));

        // Deploy CU behind proxy with CR and CRA addresses
        ConsumptionUnitUpgradeable cuImpl = new ConsumptionUnitUpgradeable();
        bytes memory cuInit = abi.encodeWithSelector(
            ConsumptionUnitUpgradeable.initialize.selector, address(registry), owner, address(cr), address(cra)
        );
        ERC1967Proxy cuProxy = new ERC1967Proxy(address(cuImpl), cuInit);
        cu = ConsumptionUnitUpgradeable(address(cuProxy));

        // Mark CRA active
        registry.setActive(craActive, true);

        // Deploy TributeDraft behind proxy
        TributeDraftUpgradeable tdImpl = new TributeDraftUpgradeable();
        bytes memory tdInit = abi.encodeWithSelector(TributeDraftUpgradeable.initialize.selector, address(cu));
        ERC1967Proxy tdProxy = new ERC1967Proxy(address(tdImpl), tdInit);
        td = TributeDraftUpgradeable(address(tdProxy));
    }

    // helper: submit a single CR and CU and return their hashes
    function _submitCR(bytes32 crHash) internal {
        string[] memory keys = new string[](1);
        keys[0] = "k";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));
        vm.prank(craActive);
        cr.submit(crHash, recordOwner, keys, values);
    }

    function _submitCU(bytes32 cuHash, bytes32 crHash, uint64 base, uint128 atto) internal {
        // Ensure CR exists for CU linkage
        _submitCR(crHash);
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = crHash;
        vm.prank(craActive);
        cu.submit(cuHash, recordOwner, currency, worldwideDay, base, atto, crHashes, new bytes32[](0));
    }

    function test_submit_success_persists_entity_aggregates_and_emits() public {
        // seed two CUs
        bytes32 cu1 = keccak256("cu-1");
        bytes32 cu2 = keccak256("cu-2");
        _submitCU(cu1, keccak256("cr-1"), 5, 9e17);
        _submitCU(cu2, keccak256("cr-2"), 7, 6e17);

        uint256 ts = 1_800_000_000;
        vm.warp(ts);

        bytes32[] memory cuHashes = new bytes32[](2);
        cuHashes[0] = cu1;
        cuHashes[1] = cu2;

        // Expected tdId matches contract computation
        bytes32 expectedId = keccak256(abi.encode(recordOwner, worldwideDay, cuHashes));

        vm.expectEmit(true, true, true, true);
        emit ITributeDraft.Submitted(expectedId, recordOwner, recordOwner, 2, ts);

        vm.prank(recordOwner);
        bytes32 tdId = td.submit(cuHashes);
        assertEq(tdId, expectedId);

        // Verify persisted entity
        ITributeDraft.TributeDraftEntity memory e = td.getTributeDraft(tdId);
        assertEq(e.tributeDraftId, expectedId);
        assertEq(e.owner, recordOwner);
        assertEq(e.settlementCurrency, currency);
        assertEq(e.worldwideDay, worldwideDay);
        // Aggregation with carry: (5 + 7) + carry from 0.9e18 + 0.6e18 = 1.5e18 -> +1 base, 0.5e18 atto
        assertEq(e.settlementAmountBase, 13);
        assertEq(e.settlementAmountAtto, 5e17);
        assertEq(e.cuHashes.length, 2);
        assertEq(e.cuHashes[0], cu1);
        assertEq(e.cuHashes[1], cu2);
        assertEq(e.submittedAt, ts);

        // totalSupply increments
        assertEq(td.totalSupply(), 1);
    }

    function test_submit_reverts_on_empty_array() public {
        bytes32[] memory empty;
        vm.expectRevert(ITributeDraft.EmptyArray.selector);
        td.submit(empty);
    }

    function test_submit_reverts_on_duplicate_cu_in_input() public {
        bytes32 cu1 = keccak256("cu-dup");
        _submitCU(cu1, keccak256("cr-dup"), 1, 1);

        bytes32[] memory cuHashes = new bytes32[](2);
        cuHashes[0] = cu1;
        cuHashes[1] = cu1; // duplicate

        vm.prank(recordOwner);
        vm.expectRevert(ITributeDraft.AlreadyExists.selector);
        td.submit(cuHashes);
    }

    function test_submit_reverts_when_cu_already_used_before() public {
        bytes32 cu1 = keccak256("cu-used-1");
        bytes32 cu2 = keccak256("cu-used-2");
        bytes32 cu3 = keccak256("cu-used-3");
        _submitCU(cu1, keccak256("cr-used-1"), 2, 0);
        _submitCU(cu2, keccak256("cr-used-2"), 3, 0);
        _submitCU(cu3, keccak256("cr-used-3"), 4, 0);

        // First submission consumes CU1 and CU2
        bytes32[] memory first = new bytes32[](2);
        first[0] = cu1;
        first[1] = cu2;
        vm.prank(recordOwner);
        td.submit(first);

        // Second submission tries to reuse CU1
        bytes32[] memory second = new bytes32[](2);
        second[0] = cu1;
        second[1] = cu3;
        vm.prank(recordOwner);
        vm.expectRevert(ITributeDraft.AlreadyExists.selector);
        td.submit(second);
    }

    function test_submit_reverts_when_cu_not_found() public {
        bytes32 missing = keccak256("cu-missing");
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = missing;
        vm.prank(recordOwner);
        vm.expectRevert(abi.encodeWithSelector(ITributeDraft.NotFound.selector, missing));
        td.submit(arr);
    }

    function test_submit_reverts_when_caller_not_owner_of_first_cu() public {
        bytes32 cu1 = keccak256("cu-not-owner");
        _submitCU(cu1, keccak256("cr-not-owner"), 1, 0);
        bytes32[] memory arr = new bytes32[](1);
        arr[0] = cu1;
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(ITributeDraft.NotSameOwner.selector, cu1));
        td.submit(arr);
    }

    function test_submit_reverts_when_different_owner_in_list() public {
        // CU1 owned by recordOwner
        bytes32 cu1 = keccak256("cu-owner-1");
        _submitCU(cu1, keccak256("cr-owner-1"), 1, 0);

        // Create CU2 owned by a different owner by submitting CR and CU with different owner
        // We need to submit CR with other as owner and CU with other as owner, so adjust helper inline here
        // submit CR for other
        string[] memory keys = new string[](1);
        keys[0] = "k";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(1));
        vm.prank(craActive);
        cr.submit(keccak256("cr-owner-2"), other, keys, values);
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("cr-owner-2");
        bytes32 cu2 = keccak256("cu-owner-2");
        vm.prank(craActive);
        cu.submit(cu2, other, currency, worldwideDay, 2, 0, crHashes, new bytes32[](0));

        bytes32[] memory arr = new bytes32[](2);
        arr[0] = cu1;
        arr[1] = cu2;

        vm.prank(recordOwner);
        vm.expectRevert(abi.encodeWithSelector(ITributeDraft.NotSameOwner.selector, cu2));
        td.submit(arr);
    }

    function test_submit_reverts_on_currency_mismatch() public {
        bytes32 cu1 = keccak256("cu-cur-1");
        _submitCU(cu1, keccak256("cr-cur-1"), 1, 0);

        // Make a CU with different currency for same owner/day
        bytes32 cr2 = keccak256("cr-cur-2");
        _submitCR(cr2);
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = cr2;
        bytes32 cu2 = keccak256("cu-cur-2");
        vm.prank(craActive);
        cu.submit(cu2, recordOwner, 840, worldwideDay, 1, 0, crHashes, new bytes32[](0));

        bytes32[] memory arr = new bytes32[](2);
        arr[0] = cu1;
        arr[1] = cu2;

        vm.prank(recordOwner);
        vm.expectRevert(ITributeDraft.NotSettlementCurrencyCurrency.selector);
        td.submit(arr);
    }

    function test_submit_reverts_on_worldwideDay_mismatch() public {
        bytes32 cu1 = keccak256("cu-day-1");
        _submitCU(cu1, keccak256("cr-day-1"), 1, 0);

        // CU with different day
        bytes32 cr2 = keccak256("cr-day-2");
        _submitCR(cr2);
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = cr2;
        bytes32 cu2 = keccak256("cu-day-2");
        vm.prank(craActive);
        cu.submit(cu2, recordOwner, currency, worldwideDay + 1, 1, 0, crHashes, new bytes32[](0));

        bytes32[] memory arr = new bytes32[](2);
        arr[0] = cu1;
        arr[1] = cu2;

        vm.prank(recordOwner);
        vm.expectRevert(ITributeDraft.NotSameWorldwideDay.selector);
        td.submit(arr);
    }
}
