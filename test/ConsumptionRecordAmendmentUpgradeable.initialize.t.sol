// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./helpers.t.sol" as TestUtils;
import {
    ConsumptionRecordAmendmentUpgradeable
} from "../src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICRAAware} from "src/interfaces/ICRAAware.sol";
import {Test} from "forge-std/Test.sol";

contract ConsumptionRecordAmendmentUpgradeableInitializeTest is Test {
    ConsumptionRecordAmendmentUpgradeable cra;
    TestUtils.MockCRARegistry registry;

    address owner = address(0xABCD);

    function setUp() public {
        registry = new TestUtils.MockCRARegistry();
    }

    function _deployInitializedProxy(address craRegistry, address newOwner)
        internal
        returns (ConsumptionRecordAmendmentUpgradeable)
    {
        ConsumptionRecordAmendmentUpgradeable impl = new ConsumptionRecordAmendmentUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordAmendmentUpgradeable.initialize.selector, craRegistry, newOwner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        return ConsumptionRecordAmendmentUpgradeable(address(proxy));
    }

    function test_initialize_setsOwner_andCRARegistry() public {
        cra = _deployInitializedProxy(address(registry), owner);

        // owner() is exposed via getOwner() helper
        assertEq(cra.owner(), owner);
        // CRA registry address is exposed by ICRAAware.getCRARegistry
        assertEq(ICRAAware(address(cra)).getCRARegistry(), address(registry));
    }

    function test_initialize_reverts_when_craRegistry_zero() public {
        ConsumptionRecordAmendmentUpgradeable impl = new ConsumptionRecordAmendmentUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionRecordAmendmentUpgradeable.initialize.selector, address(0), owner);
        vm.expectRevert(bytes("CRA Registry cannot be zero address"));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_initialize_reverts_when_owner_zero() public {
        ConsumptionRecordAmendmentUpgradeable impl = new ConsumptionRecordAmendmentUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            ConsumptionRecordAmendmentUpgradeable.initialize.selector, address(registry), address(0)
        );
        vm.expectRevert(bytes("Owner cannot be zero address"));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_initialize_reverts_when_called_twice_on_proxy() public {
        cra = _deployInitializedProxy(address(registry), owner);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        cra.initialize(address(registry), owner);
    }

    function test_initialize_reverts_on_implementation_due_to_disabled_initializers() public {
        ConsumptionRecordAmendmentUpgradeable impl = new ConsumptionRecordAmendmentUpgradeable();
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        impl.initialize(address(registry), owner);
    }
}
