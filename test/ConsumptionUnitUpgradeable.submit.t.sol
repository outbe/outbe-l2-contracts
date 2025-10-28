// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConsumptionRecordUpgradeable} from "src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ConsumptionRecordAmendmentUpgradeable} from "src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {ConsumptionUnitUpgradeable} from "src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {IConsumptionUnit} from "src/interfaces/IConsumptionUnit.sol";
import {MockCRARegistry} from "./helpers.t.sol";
import {ISoulBoundToken} from "../src/interfaces/ISoulBoundToken.sol";
import {ICRAAware} from "../src/interfaces/ICRAAware.sol";

contract ConsumptionUnitUpgradeableSubmitTest is Test {
    ConsumptionRecordUpgradeable cr;
    ConsumptionRecordAmendmentUpgradeable cra;
    ConsumptionUnitUpgradeable cu;
    MockCRARegistry registry;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address craInactive = address(0xDEAD);
    address recordOwner = address(0xBEEF);

    uint256[] private  defaultCrHashes;
    uint256 private  defaultCuId = uint256(keccak256("cu-seed"));


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

            defaultCrHashes = new uint256[](1);
            defaultCrHashes[0] = uint256(keccak256("cr-seed"));

            cr.submit(defaultCrHashes[0], recordOwner, keys, vals);
        }

        // Deploy CRA (Consumption Record Amendment) and initialize via ERC1967Proxy
        {
            ConsumptionRecordAmendmentUpgradeable implCRA = new ConsumptionRecordAmendmentUpgradeable();
            bytes memory initCRA = abi.encodeWithSelector(
                ConsumptionRecordAmendmentUpgradeable.initialize.selector, address(registry), owner
            );
            ERC1967Proxy proxyCRA = new ERC1967Proxy(address(implCRA), initCRA);
            cra = ConsumptionRecordAmendmentUpgradeable(address(proxyCRA));
        }

        // Seed one CRA so that CU can reference it
        {
            string[] memory keys = new string[](1);
            bytes32[] memory vals = new bytes32[](1);
            keys[0] = "seed";
            vals[0] = bytes32(uint256(1));
            vm.prank(craActive);
            cra.submit(uint256(keccak256("cra-seed")), recordOwner, keys, vals);
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

    function _seedCRA(uint256 craHash) internal {
        string[] memory keys = new string[](1);
        bytes32[] memory vals = new bytes32[](1);
        keys[0] = "k";
        vals[0] = bytes32(uint256(123));
        vm.prank(craActive);
        cra.submit(craHash, recordOwner, keys, vals);
    }

    function test_submit_persists_full_entity_and_indexes_and_emits_event() public {
        // prepare CRs to link
        uint256 crHash = uint256(keccak256("cr-ok"));
        _seedCR(crHash);
        // prepare amendment CRs to link
        uint256 amendHash = uint256(keccak256("cr-amend-ok"));
        _seedCRA(amendHash);

        uint256 cuHash = uint256(keccak256("cu-1"));
        uint16 currency = 840; // USD
        uint32 wday = 20250923;
        uint64 baseAmt = 10;
        uint128 attoAmt = 5;
        uint256[] memory crHashes = new uint256[](1);
        crHashes[0] = crHash;
        uint256[] memory amendmentHashes = new uint256[](1);
        amendmentHashes[0] = amendHash;

        uint256 ts = 1_800_000_000;
        vm.warp(ts);

        vm.expectEmit(true, true, false, true);
        emit ISoulBoundToken.Minted(craActive, recordOwner, cuHash);

        vm.prank(craActive);
        cu.submit(cuHash, recordOwner, currency, wday, baseAmt, attoAmt, crHashes, amendmentHashes);

        // isExists
        assertTrue(cu.exists(cuHash));

        // entity fields
        IConsumptionUnit.ConsumptionUnitEntity memory e = cu.getTokenData(cuHash);
        assertEq(e.owner, recordOwner);
        assertEq(e.submittedBy, craActive);
        assertEq(e.submittedAt, ts);
        assertEq(e.settlementCurrency, currency);
        assertEq(e.worldwideDay, wday);
        assertEq(e.settlementAmountBase, baseAmt);
        assertEq(e.settlementAmountAtto, attoAmt);
        assertEq(e.crIds.length, 1);
        assertEq(e.crIds[0], crHash);
        assertEq(e.amendmentCrIds.length, 1);
        assertEq(e.amendmentCrIds[0], amendHash);

        assertEq(cu.balanceOf(recordOwner), 1);

        // totalSupply tracks count
        assertEq(cu.totalSupply(), 1);
    }

    function test_submit_reverts_on_zero_hash() public {
        vm.prank(craActive);
        vm.expectRevert(ISoulBoundToken.InvalidTokenId.selector);
        cu.submit(uint256(0), recordOwner, 978, 20250101, 1, 0, defaultCrHashes, new uint256[](0));
    }

    function test_submit_reverts_on_zero_owner() public {
        vm.prank(craActive);
        vm.expectRevert("ERC721: mint to the zero address");
        cu.submit(defaultCuId, address(0), 978, 20250101, 1, 0, defaultCrHashes, new uint256[](0));
    }

    function test_submit_reverts_on_invalid_currency_zero() public {
        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidSettlementCurrency.selector);
        cu.submit(defaultCuId, recordOwner, 0, 20250101, 1, 0, defaultCrHashes, new uint256[](0));
    }

    function test_submit_reverts_on_invalid_amount_both_zero() public {
        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidAmount.selector);
        cu.submit(defaultCuId, recordOwner, 978, 20250101, 0, 0, defaultCrHashes, new uint256[](0));
    }

    function test_submit_reverts_on_invalid_amount_atto_ge_1e18() public {
        vm.prank(craActive);
        vm.expectRevert(IConsumptionUnit.InvalidAmount.selector);
        cu.submit(defaultCuId, recordOwner, 978, 20250101, 0, uint128(1e18), defaultCrHashes, new uint256[](0));
    }

        function test_submit_reverts_on_empty_cr_hashes() public {
            uint256 [] memory crHashes = new uint256[](0);

            vm.prank(craActive);
            vm.expectRevert(IConsumptionUnit.InvalidConsumptionRecords.selector);
            cu.submit(defaultCuId, recordOwner, 978, 20250101, 1, 0, crHashes, new uint256[](0));
        }

        function test_submit_reverts_on_unknown_cr_hash() public {
            uint256[] memory crHashes = new uint256[](1);
            crHashes[0] = uint256(keccak256("cr-unknown"));

            vm.prank(craActive);
            vm.expectRevert(IConsumptionUnit.InvalidConsumptionRecords.selector);
            cu.submit(defaultCuId, recordOwner, 978, 20250101, 1, 0, crHashes, new uint256[](0));
        }

        function test_submit_reverts_on_duplicate_cr_hash_in_input_array() public {
            uint256  h = uint256 (keccak256("cr-dupe"));
            _seedCR(h);
            uint256[] memory crHashes = new uint256[](2);
            crHashes[0] = h;
            crHashes[1] = h;

            vm.prank(craActive);
            vm.expectRevert(IConsumptionUnit.ConsumptionRecordAlreadyExists.selector);
            cu.submit(defaultCuId, recordOwner, 978, 20250101, 1, 0, crHashes, new uint256[](0));
        }

        function test_submit_reverts_on_cr_hash_used_globally_before() public {
            uint256  h = uint256 (keccak256("cr-used"));
            _seedCR(h);

            uint256[] memory arr = new uint256[](1);
            arr[0] = h;

            vm.startPrank(craActive);
            cu.submit(uint256(keccak256("cu-first")), recordOwner, 978, 20250101, 1, 0, arr, new uint256 [](0));
            vm.expectRevert(IConsumptionUnit.ConsumptionRecordAlreadyExists.selector);
            cu.submit(uint256(keccak256("cu-second")), recordOwner, 978, 20250101, 2, 0, arr, new uint256[](0));
            vm.stopPrank();
        }

        function test_submit_reverts_on_duplicate_cu_hash() public {
            uint256 h = uint256(keccak256("cr-other"));
            _seedCR(h);

            uint256[] memory arr = new uint256[](1);
            arr[0] = h;

        vm.startPrank(craActive);
            uint256 cuHash = uint256(keccak256("cu-dup"));
            cu.submit(cuHash, recordOwner, 978, 20250101, 1, 0, defaultCrHashes, new uint256 [](0));
            vm.expectRevert(ISoulBoundToken.AlreadyExists.selector);
            cu.submit(cuHash, recordOwner, 978, 20250101, 1, 0, arr, new uint256[](0));
            vm.stopPrank();
        }

        function test_submit_reverts_for_inactive_or_unknown_CRA() public {
            vm.prank(craInactive);
            vm.expectRevert(ICRAAware.CRANotActive.selector);
            cu.submit(defaultCuId, recordOwner, 978, 20250101, 1, 0, defaultCrHashes, new uint256[](0));

            address craUnknown = address(0xEefe);
            vm.prank(craUnknown);
            vm.expectRevert(ICRAAware.CRANotActive.selector);
            cu.submit(defaultCuId, recordOwner, 978, 20250101, 1, 0, defaultCrHashes, new uint256[](0));
        }

    //    // Amendment hashes tests
    //    function test_submit_reverts_on_unknown_amendment_hash() public {
    //        // seed base CR only
    //        bytes32 base = keccak256("cr-amend-unknown-base");
    //        _seedCR(base);
    //        bytes32 unknown = keccak256("cr-amend-unknown"); // not seeded
    //        bytes32[] memory crHashes = new bytes32[](1);
    //        crHashes[0] = base;
    //        bytes32[] memory amendmentHashes = new bytes32[](1);
    //        amendmentHashes[0] = unknown;
    //
    //        vm.prank(craActive);
    //        vm.expectRevert(IConsumptionUnit.InvalidConsumptionRecords.selector);
    //        cu.submit(keccak256("cu-amend-unknown"), recordOwner, 978, 20250101, 1, 0, crHashes, amendmentHashes);
    //    }
    //
    //    function test_submit_reverts_on_duplicate_amendment_hash_in_input_array() public {
    //        bytes32 base = keccak256("cr-amend-dupe-base");
    //        _seedCR(base);
    //        bytes32 amend = keccak256("cr-amend-dupe");
    //        _seedCRA(amend);
    //        bytes32[] memory crHashes = new bytes32[](1);
    //        crHashes[0] = base;
    //        bytes32[] memory amendmentHashes = new bytes32[](2);
    //        amendmentHashes[0] = amend;
    //        amendmentHashes[1] = amend;
    //
    //        vm.prank(craActive);
    //        vm.expectRevert(IConsumptionUnit.ConsumptionRecordAlreadyExists.selector);
    //        cu.submit(keccak256("cu-amend-dupe"), recordOwner, 978, 20250101, 1, 0, crHashes, amendmentHashes);
    //    }
    //
    //    function test_submit_reverts_on_amendment_hash_used_globally_before() public {
    //        bytes32 base1 = keccak256("cr-amend-used-base1");
    //        _seedCR(base1);
    //        bytes32 amend = keccak256("cr-amend-used");
    //        _seedCRA(amend);
    //
    //        bytes32[] memory crHashes1 = new bytes32[](1);
    //        crHashes1[0] = base1;
    //        bytes32[] memory amendment1 = new bytes32[](1);
    //        amendment1[0] = amend;
    //
    //        vm.startPrank(craActive);
    //        cu.submit(keccak256("cu-amend-first"), recordOwner, 978, 20250101, 1, 0, crHashes1, amendment1);
    //        vm.stopPrank();
    //
    //        // now try to reuse the same amendment hash in another CU
    //        bytes32 base2 = keccak256("cr-amend-used-base2");
    //        _seedCR(base2);
    //        bytes32[] memory crHashes2 = new bytes32[](1);
    //        crHashes2[0] = base2;
    //        bytes32[] memory amendment2 = new bytes32[](1);
    //        amendment2[0] = amend;
    //
    //        vm.prank(craActive);
    //        vm.expectRevert(IConsumptionUnit.ConsumptionRecordAlreadyExists.selector);
    //        cu.submit(keccak256("cu-amend-second"), recordOwner, 978, 20250101, 2, 0, crHashes2, amendment2);
    //    }
    //
    //    function test_submit_reverts_when_amendment_and_base_overlap_in_same_submission() public {
    //        // same CR hash appears in both arrays
    //        bytes32 h = keccak256("cr-amend-overlap");
    //        _seedCR(h);
    //        bytes32[] memory baseArr = new bytes32[](1);
    //        baseArr[0] = h;
    //        bytes32[] memory amendArr = new bytes32[](1);
    //        amendArr[0] = h;
    //
    //        vm.prank(craActive);
    //        vm.expectRevert(IConsumptionUnit.InvalidConsumptionRecords.selector);
    //        cu.submit(keccak256("cu-amend-overlap"), recordOwner, 978, 20250101, 1, 0, baseArr, amendArr);
    //    }
}
