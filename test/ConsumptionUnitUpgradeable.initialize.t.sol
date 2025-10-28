// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./helpers.t.sol" as TestUtils;
import {ConsumptionUnitUpgradeable} from "src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICRAAware} from "src/interfaces/ICRAAware.sol";
import {Test} from "forge-std/Test.sol";

contract ConsumptionUnitUpgradeableInitializeTest is Test {
    ConsumptionUnitUpgradeable cu;
    TestUtils.MockCRARegistry registry;

    address owner = address(0xABCD);
    address cr = address(0x123ff);
    address cra = address(0x456ff);

    function setUp() public {
        registry = new TestUtils.MockCRARegistry();
    }

    function _deployInitializedProxy(address craRegistry, address newOwner)
        internal
        returns (ConsumptionUnitUpgradeable)
    {
        ConsumptionUnitUpgradeable impl = new ConsumptionUnitUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionUnitUpgradeable.initialize.selector, craRegistry, newOwner, cr, cra);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        return ConsumptionUnitUpgradeable(address(proxy));
    }

    function test_initialize_setsOwner_andCRARegistry() public {
        cu = _deployInitializedProxy(address(registry), owner);

        // owner() is exposed via getOwner() helper
        assertEq(cu.owner(), owner);
        // CRA registry address is exposed by ICRAAware.getCRARegistry
        assertEq(ICRAAware(address(cu)).getCRARegistry(), address(registry));
    }

    function test_initialize_reverts_when_craRegistry_zero() public {
        ConsumptionUnitUpgradeable impl = new ConsumptionUnitUpgradeable();
        bytes memory initData =
            abi.encodeWithSelector(ConsumptionUnitUpgradeable.initialize.selector, address(0), owner, cr, cra);
        vm.expectRevert(bytes("CRARegistry address is zero"));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_initialize_reverts_when_owner_zero() public {
        ConsumptionUnitUpgradeable impl = new ConsumptionUnitUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            ConsumptionUnitUpgradeable.initialize.selector, address(registry), address(0), cr, cra
        );
        vm.expectRevert(bytes("Owner cannot be zero address"));
        new ERC1967Proxy(address(impl), initData);
    }

    function test_initialize_reverts_when_called_twice_on_proxy() public {
        cu = _deployInitializedProxy(address(registry), owner);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        cu.initialize(address(registry), owner, cr, cra);
    }

    function test_initialize_reverts_on_implementation_due_to_disabled_initializers() public {
        ConsumptionUnitUpgradeable impl = new ConsumptionUnitUpgradeable();
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        impl.initialize(address(registry), owner, cr, cra);
    }
}
