// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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
        uint256  crHash = uint256 (keccak256("cr1"));
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = "k1";
        values[0] = bytes32(uint256(123));

        vm.prank(craActive);
        cr.submit(crHash, recordOwner, keys, values);

        // check persisted
        assertTrue(cr.exists(crHash));
        IConsumptionRecord.ConsumptionRecordEntity memory e = cr.getTokenData(crHash);
        assertEq(e.submittedBy, craActive);
        assertEq(e.owner, recordOwner);
    }

    function test_submit_reverts_for_inactiveCRA() public {
        uint256 crHash = uint256(keccak256("cr2"));
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = "k1";
        values[0] = bytes32(uint256(456));

        vm.prank(craInactive);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cr.submit(crHash, recordOwner, keys, values);
    }

    function test_submit_reverts_for_unknownCRA() public {
        uint256 crHash = uint256( keccak256("cr3"));
        string[] memory keys = new string[](1);
        bytes32[] memory values = new bytes32[](1);
        keys[0] = "k1";
        values[0] = bytes32(uint256(456));

        address craUnknown = address(0xEF123);
        vm.prank(craUnknown);
        vm.expectRevert(ICRAAware.CRANotActive.selector);
        cr.submit(crHash, recordOwner, keys, values);
    }
}
