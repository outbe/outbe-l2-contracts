// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CRARegistry} from "../../src/cra_registry/CRARegistry.sol";
import {ICRARegistry} from "../../src/interfaces/ICRARegistry.sol";

contract CRARegistryTest is Test {
    CRARegistry public registry;
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

        registry = new CRARegistry();
    }

    function test_InitialState() public view {
        assertEq(registry.getOwner(), owner);
        assertEq(registry.getAllCras().length, 0);

        address[] memory cras = registry.getAllCras();
        assertEq(cras.length, 0);
    }

    function test_RegisterCRA() public {
        string memory name = "Test CRA";

        vm.expectEmit(true, false, false, true);
        emit CRARegistered(cra1, name, block.timestamp);

        registry.registerCra(cra1, name);

        assertTrue(registry.isCraActive(cra1));
        assertEq(registry.getAllCras().length, 1);

        ICRARegistry.CraInfo memory info = registry.getCraInfo(cra1);
        assertEq(info.name, name);
        assertEq(uint256(info.status), uint256(ICRARegistry.CRAStatus.Active));
        assertEq(info.registeredAt, block.timestamp);

        address[] memory cras = registry.getAllCras();
        assertEq(cras.length, 1);
        assertEq(cras[0], cra1);
    }

    function test_RegisterCRA_RevertWhen_NotOwner() public {
        vm.prank(unauthorized);
        vm.expectRevert(ICRARegistry.UnauthorizedAccess.selector);
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
        vm.expectRevert(ICRARegistry.UnauthorizedAccess.selector);
        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);
    }

    function test_UpdateCRAStatus_RevertWhen_CRANotFound() public {
        vm.expectRevert(ICRARegistry.CRANotFound.selector);
        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);
    }

    function test_IsCRAActive_Different_Statuses() public {
        registry.registerCra(cra1, "Test CRA");
        assertTrue(registry.isCraActive(cra1));

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Inactive);
        assertFalse(registry.isCraActive(cra1));

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);
        assertFalse(registry.isCraActive(cra1));

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Active);
        assertTrue(registry.isCraActive(cra1));
    }

    function test_IsCRAActive_NotRegistered() public view {
        assertFalse(registry.isCraActive(cra1));
    }

    function test_GetCRAInfo_RevertWhen_NotFound() public {
        vm.expectRevert(ICRARegistry.CRANotFound.selector);
        registry.getCraInfo(cra1);
    }

    function test_Multiple_CRAs() public {
        registry.registerCra(cra1, "CRA One");
        registry.registerCra(cra2, "CRA Two");

        assertEq(registry.getAllCras().length, 2);

        address[] memory cras = registry.getAllCras();
        assertEq(cras.length, 2);
        assertEq(cras[0], cra1);
        assertEq(cras[1], cra2);

        assertTrue(registry.isCraActive(cra1));
        assertTrue(registry.isCraActive(cra2));

        registry.updateCraStatus(cra1, ICRARegistry.CRAStatus.Suspended);

        assertFalse(registry.isCraActive(cra1));
        assertTrue(registry.isCraActive(cra2));
    }

    function test_OwnershipCheck() public view {
        assertEq(registry.getOwner(), owner);
    }

    function testFuzz_RegisterCRA(string memory name) public {
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(name).length < 1000);

        registry.registerCra(cra1, name);

        ICRARegistry.CraInfo memory info = registry.getCraInfo(cra1);
        assertEq(info.name, name);
        assertTrue(registry.isCraActive(cra1));
    }

    function testFuzz_RegisterCRA_EmptyName_Reverts(string memory name) public {
        vm.assume(bytes(name).length == 0);

        vm.expectRevert(ICRARegistry.EmptyCRAName.selector);
        registry.registerCra(cra1, name);
    }
}
