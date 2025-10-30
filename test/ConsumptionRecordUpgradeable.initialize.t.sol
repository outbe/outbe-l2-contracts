// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./helpers.t.sol" as TestUtils;
import {ConsumptionRecordUpgradeable} from "../src/consumption_record/ConsumptionRecordUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICRAAware} from "src/interfaces/ICRAAware.sol";
import {Test} from "forge-std/Test.sol";

contract ConsumptionRecordUpgradeableInitializeTest is Test {
    ConsumptionRecordUpgradeable cr;
    TestUtils.MockCRARegistry registry;

    address owner = address(0xABCD);

    function setUp() public {
        registry = new TestUtils.MockCRARegistry();
    }

    function _deployInitializedProxy(address craRegistry, address newOwner)
        internal
        returns (ConsumptionRecordUpgradeable)
    {
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, craRegistry, newOwner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        return ConsumptionRecordUpgradeable(address(proxy));
    }

    function test_initialize_setsOwner_andCRARegistry() public {
        cr = _deployInitializedProxy(address(registry), owner);

        // owner() is exposed via getOwner() helper
        assertEq(cr.owner(), owner);
        // CRA registry address is exposed by ICRAAware.getCRARegistry
        assertEq(ICRAAware(address(cr)).getCRARegistry(), address(registry));
    }

    function test_initialize_reverts_when_craRegistry_zero() public {
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(0), owner);
        vm.expectRevert(bytes("CRA Registry cannot be zero address"));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_initialize_reverts_when_owner_zero() public {
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordUpgradeable.initialize.selector, address(registry), address(0));
        vm.expectRevert(bytes("Owner cannot be zero address"));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_initialize_reverts_when_called_twice_on_proxy() public {
        cr = _deployInitializedProxy(address(registry), owner);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        cr.initialize(address(registry), owner);
    }

    function test_initialize_reverts_on_implementation_due_to_disabled_initializers() public {
        ConsumptionRecordUpgradeable impl = new ConsumptionRecordUpgradeable();
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        impl.initialize(address(registry), owner);
    }
}
