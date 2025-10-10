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
import {ICRAAware} from "../src/interfaces/ICRAAware.sol";
import {IConsumptionRecord} from "../src/interfaces/IConsumptionRecord.sol";
import {MockCRARegistry} from "./helpers.t.sol";

contract ConsumptionRecordUpgradeableOnlyActiveTest is Test {
    ConsumptionRecordUpgradeable cr;
    MockCRARegistry registry;

    address owner = address(0xABCD);
    address craActive = address(0xCAFE);
    address craInactive = address(0xDEAD);
    address recordOwner = address(0xBEEF);

    function setUp() public {
        registry = new MockCRARegistry();

        // Deploy implementation and initialize via ERC1967Proxy
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(registry), owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        cr = ConsumptionRecordUpgradeable(address(proxy));

        // mark the active CRA as active in registry
        registry.setActive(craActive, true);
        registry.setActive(craInactive, false);
    }

    function test_submit_succeeds_for_activeCRA() public {
        bytes32 crHash = keccak256("cr1");
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = "k1";
        values[0] = bytes32(uint256(123));

        vm.prank(craActive);
        cr.submit(crHash, recordOwner, keys, values);

        // check persisted
        assertTrue(cr.isExists(crHash));
        IConsumptionRecord.ConsumptionRecordEntity memory e = cr.getConsumptionRecord(crHash);
        assertEq(e.submittedBy, craActive);
        assertEq(e.owner, recordOwner);
    }

    function test_submit_reverts_for_inactiveCRA() public {
        bytes32 crHash = keccak256("cr2");
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = "k1";
        values[0] = bytes32(uint256(456));

        vm.prank(craInactive);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cr.submit(crHash, recordOwner, keys, values);
    }

    function test_submit_reverts_for_unknownCRA() public {
        bytes32 crHash = keccak256("cr3");
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = "k1";
        values[0] = bytes32(uint256(456));

        address craUnknown = address(0xEF123);
        vm.prank(craUnknown);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cr.submit(crHash, recordOwner, keys, values);
    }

    function test_submitBatch_succeeds_for_activeCRA() public {
        bytes32[] memory crHashes = new bytes32[](2);
        crHashes[0] = keccak256("b1");
        crHashes[1] = keccak256("b2");

        address[] memory owners = new address[](2);
        owners[0] = recordOwner;
        owners[1] = recordOwner;

        string[][] memory keysArray = new string[][](2);
        keysArray[0] = new string[](1);
        keysArray[0][0] = "k";
        keysArray[1] = new string[](1);
        keysArray[1][0] = "k";

        bytes32[][] memory valuesArray = new bytes32[][](2);
        valuesArray[0] = new bytes32[](1);
        valuesArray[0][0] = bytes32(uint256(1));
        valuesArray[1] = new bytes32[](1);
        valuesArray[1][0] = bytes32(uint256(2));

        vm.prank(craActive);
        cr.submitBatch(crHashes, owners, keysArray, valuesArray);

        assertTrue(cr.isExists(crHashes[0]));
        assertTrue(cr.isExists(crHashes[1]));
        IConsumptionRecord.ConsumptionRecordEntity memory e1 = cr.getConsumptionRecord(crHashes[0]);
        IConsumptionRecord.ConsumptionRecordEntity memory e2 = cr.getConsumptionRecord(crHashes[1]);
        assertEq(e1.submittedBy, craActive);
        assertEq(e2.submittedBy, craActive);
    }

    function test_submitBatch_reverts_for_inactiveCRA() public {
        bytes32[] memory crHashes = new bytes32[](1);
        crHashes[0] = keccak256("b3");

        address[] memory owners = new address[](1);
        owners[0] = recordOwner;

        string[][] memory keysArray = new string[][](1);
        keysArray[0] = new string[](1);
        keysArray[0][0] = "k";

        bytes32[][] memory valuesArray = new bytes32[][](1);
        valuesArray[0] = new bytes32[](1);
        valuesArray[0][0] = bytes32(uint256(3));

        vm.prank(craInactive);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cr.submitBatch(crHashes, owners, keysArray, valuesArray);
    }
}
