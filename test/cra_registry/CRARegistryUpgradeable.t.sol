// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CRARegistryUpgradeable} from "../../src/cra_registry/CRARegistryUpgradeable.sol";
import {ICRARegistry} from "../../src/interfaces/ICRARegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CRARegistryUpgradeableTest is Test {
    CRARegistryUpgradeable public registry;
    CRARegistryUpgradeable public implementation;
    ERC1967Proxy public proxy;

    address public owner;
    address public cra1;
    address public cra2;
    address public unauthorized;

    event CRARegistered(address indexed cra, string name, uint256 timestamp);
    event CRAStatusUpdated(
        address indexed cra, ICRARegistry.CRAStatus oldStatus, ICRARegistry.CRAStatus newStatus, uint256 timestamp
    );

    function setUp() public {
        owner = address(this);
        cra1 = makeAddr("cra1");
        cra2 = makeAddr("cra2");
        unauthorized = makeAddr("unauthorized");

        // Deploy implementation
        implementation = new CRARegistryUpgradeable();

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSignature("initialize(address)", owner);
        proxy = new ERC1967Proxy(address(implementation), initData);
        registry = CRARegistryUpgradeable(address(proxy));
    }

    function test_InitialState() public view {
        assertEq(registry.getOwner(), owner);
        assertEq(registry.getAllCras().length, 0);
        assertEq(registry.VERSION(), "1.0.0");

        address[] memory cras = registry.getAllCras();
        assertEq(cras.length, 0);
    }

    function test_Initialize_RevertWhen_ZeroOwner() public {
        CRARegistryUpgradeable newImpl = new CRARegistryUpgradeable();

        bytes memory initData = abi.encodeWithSignature("initialize(address)", address(0));

        vm.expectRevert("Owner cannot be zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_RegisterCRA() public {
        string memory name = "Test CRA";

        vm.expectEmit(true, false, false, true);
        emit CRARegistered(cra1, name, block.timestamp);

        registry.registerCra(cra1, name);

        assertTrue(registry.isCraActive(cra1));

        ICRARegistry.CraInfo memory info = registry.getCraInfo(cra1);
        assertEq(info.name, name);
        assertEq(uint256(info.status), uint256(ICRARegistry.CRAStatus.Active));
        assertEq(info.registeredAt, block.timestamp);

        address[] memory allCras = registry.getAllCras();
        assertEq(allCras.length, 1);
        assertEq(allCras[0], cra1);
    }

    function test_RegisterCRA_RevertWhen_NotOwner() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        registry.registerCra(cra1, "Test CRA");
    }

    function test_RegisterCRA_RevertWhen_EmptyName() public {
        vm.expectRevert(ICRARegistry.EmptyCRAName.selector);
        registry.registerCra(cra1, "");
    }

    function test_RegisterCRA_RevertWhen_AlreadyRegistered() public {
        registry.registerCra(cra1, "Test CRA");

        vm.expectRevert(ICRARegistry.CRAAlreadyRegistered.selector);
        registry.registerCra(cra1, "Another CRA");
    }

    function test_UpdateCRAStatus() public {
        registry.registerCra(cra1, "Test CRA");

        vm.expectEmit(true, false, false, true);
        emit CRAStatusUpdated(cra1, ICRARegistry.CRAStatus.Active, ICRARegistry.CRAStatus.Suspended, block.timestamp);

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);

        assertFalse(registry.isCraActive(cra1));

        ICRARegistry.CraInfo memory info = registry.getCraInfo(cra1);
        assertEq(uint256(info.status), uint256(ICRARegistry.CRAStatus.Suspended));
    }

    function test_UpdateCRAStatus_RevertWhen_NotOwner() public {
        registry.registerCra(cra1, "Test CRA");

        vm.prank(unauthorized);
        vm.expectRevert();
        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);
    }

    function test_UpdateCRAStatus_RevertWhen_CRANotFound() public {
        vm.expectRevert(ICRARegistry.CRANotFound.selector);
        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);
    }

    function test_IsCraActive() public {
        assertFalse(registry.isCraActive(cra1));

        registry.registerCra(cra1, "Test CRA");
        assertTrue(registry.isCraActive(cra1));

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);
        assertFalse(registry.isCraActive(cra1));

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Active);
        assertTrue(registry.isCraActive(cra1));
    }

    function test_GetCRAInfo_RevertWhen_CRANotFound() public {
        vm.expectRevert(ICRARegistry.CRANotFound.selector);
        registry.getCraInfo(cra1);
    }

    function test_GetAllCras() public {
        address[] memory emptyCras = registry.getAllCras();
        assertEq(emptyCras.length, 0);

        registry.registerCra(cra1, "CRA One");
        registry.registerCra(cra2, "CRA Two");

        address[] memory allCras = registry.getAllCras();
        assertEq(allCras.length, 2);
        assertEq(allCras[0], cra1);
        assertEq(allCras[1], cra2);
    }

    function test_Upgrade() public {
        // Register a CRA to test data persistence
        registry.registerCra(cra1, "Test CRA");
        assertTrue(registry.isCraActive(cra1));

        // Deploy new implementation
        CRARegistryUpgradeable newImplementation = new CRARegistryUpgradeable();

        // Perform upgrade
        registry.upgradeTo(address(newImplementation));

        // Verify data persisted after upgrade
        assertTrue(registry.isCraActive(cra1));
        assertEq(registry.getOwner(), owner);

        address[] memory allCras = registry.getAllCras();
        assertEq(allCras.length, 1);
        assertEq(allCras[0], cra1);
    }

    function test_Upgrade_RevertWhen_NotOwner() public {
        CRARegistryUpgradeable newImplementation = new CRARegistryUpgradeable();

        vm.prank(unauthorized);
        vm.expectRevert();
        registry.upgradeTo(address(newImplementation));
    }

    function test_UpgradeAndCall() public {
        // Register a CRA
        registry.registerCra(cra1, "Test CRA");

        // Deploy new implementation
        CRARegistryUpgradeable newImplementation = new CRARegistryUpgradeable();

        // Prepare call data to register another CRA after upgrade
        bytes memory data = abi.encodeWithSignature("registerCra(address,string)", cra2, "CRA Two");

        // Perform upgrade and call
        registry.upgradeToAndCall(address(newImplementation), data);

        // Verify both old and new data exist
        assertTrue(registry.isCraActive(cra1));
        assertTrue(registry.isCraActive(cra2));

        address[] memory allCras = registry.getAllCras();
        assertEq(allCras.length, 2);
    }
}
