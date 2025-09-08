// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ConsumptionUnitUpgradeable} from "../../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {CRARegistryUpgradeable} from "../../src/cra_registry/CRARegistryUpgradeable.sol";
import {TributeDraftUpgradeable} from "../../src/tribute_draft/TributeDraftUpgradeable.sol";
import {IConsumptionUnit} from "../../src/interfaces/IConsumptionUnit.sol";
import {ITributeDraft} from "../../src/interfaces/ITributeDraft.sol";

contract TributeDraftUpgradeableTest is Test {
    CRARegistryUpgradeable public registry;
    ConsumptionUnitUpgradeable public cu;
    TributeDraftUpgradeable public td;

    ERC1967Proxy public registryProxy;
    ERC1967Proxy public cuProxy;

    address public owner;
    address public cra1;
    address public user;

    bytes32 public constant CU1 = keccak256("cu1");
    bytes32 public constant CU2 = keccak256("cu2");

    event Minted(
        bytes32 indexed tdId, address indexed owner, address indexed submittedBy, uint256 cuCount, uint256 timestamp
    );

    function setUp() public {
        owner = address(this);
        cra1 = makeAddr("cra1");
        user = makeAddr("user");

        // Deploy and init CRA Registry
        CRARegistryUpgradeable regImpl = new CRARegistryUpgradeable();
        bytes memory regInit = abi.encodeWithSignature("initialize(address)", owner);
        registryProxy = new ERC1967Proxy(address(regImpl), regInit);
        registry = CRARegistryUpgradeable(address(registryProxy));

        // Deploy and init CU
        ConsumptionUnitUpgradeable cuImpl = new ConsumptionUnitUpgradeable();
        bytes memory cuInit = abi.encodeWithSignature("initialize(address,address)", address(registry), owner);
        cuProxy = new ERC1967Proxy(address(cuImpl), cuInit);
        cu = ConsumptionUnitUpgradeable(address(cuProxy));

        // Register CRA
        registry.registerCra(cra1, "CRA One");

        // Deploy and init TributeDraft with CU address via proxy
        TributeDraftUpgradeable tdImpl = new TributeDraftUpgradeable();
        bytes memory tdInit = abi.encodeWithSignature("initialize(address)", address(cu));
        ERC1967Proxy tdProxy = new ERC1967Proxy(address(tdImpl), tdInit);
        td = TributeDraftUpgradeable(address(tdProxy));

        // Prepare two CU records owned by `user` and same currency USD
        _submitCU(CU1, user, "USD", 100, 5, 1, 0, "kWh", new bytes32[](0));
        _submitCU(CU2, user, "USD", 3, 1e18 - 1, 0, 0, "kWh", new bytes32[](0));
    }

    function _submitCU(
        bytes32 cuHash,
        address recordOwner,
        string memory settlementCurrency,
        uint64 settlementBaseAmount,
        uint128 settlementAttoAmount,
        uint64 nominalBaseQty,
        uint128 nominalAttoQty,
        string memory nominalCurrency,
        bytes32[] memory crHashes
    ) internal {
        vm.prank(cra1);
        cu.submit(
            cuHash,
            recordOwner,
            settlementCurrency,
            settlementBaseAmount,
            settlementAttoAmount,
            nominalBaseQty,
            nominalAttoQty,
            nominalCurrency,
            crHashes
        );
    }

    function test_InitialState() public view {
        assertEq(td.VERSION(), "1.0.0");
        assertEq(td.getConsumptionUnit(), address(cu));
    }

    function test_Mint_BasicAggregationAndEvent() public {
        bytes32[] memory cuHashes = new bytes32[](2);
        cuHashes[0] = CU1;
        cuHashes[1] = CU2;

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit Minted(keccak256(abi.encode(cuHashes)), user, user, 2, block.timestamp);
        bytes32 tdId = td.mint(cuHashes);

        // verify entity
        ITributeDraft.TributeDraftEntity memory ent = td.get(tdId);
        assertEq(ent.owner, user);
        assertEq(ent.settlementCurrency, "USD");
        // 100 + 3 + carry from atto (1e18-1 + 5) => carry 1, remainder 4
        assertEq(ent.settlementBaseAmount, uint64(104));
        assertEq(ent.settlementAttoAmount, uint128(4));
        assertEq(ent.cuHashes.length, 2);
        assertEq(ent.cuHashes[0], CU1);
        assertEq(ent.cuHashes[1], CU2);
        assertEq(ent.submittedAt, block.timestamp);
    }

    function test_Revert_When_EmptyArray() public {
        bytes32[] memory empty;
        vm.expectRevert(ITributeDraft.EmptyArray.selector);
        td.mint(empty);
    }

    function test_Revert_When_NotFound() public {
        bytes32[] memory cuHashes = new bytes32[](2);
        cuHashes[0] = CU1;
        cuHashes[1] = keccak256("missing");
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ITributeDraft.NotFound.selector, cuHashes[1]));
        td.mint(cuHashes);
    }

    function test_Revert_When_NotSameOwner() public {
        // make CU2 owned by another user2
        address user2 = makeAddr("user2");
        _submitCU(keccak256("cu3"), user2, "USD", 1, 0, 0, 0, "kWh", new bytes32[](0));
        bytes32[] memory cuHashes = new bytes32[](2);
        cuHashes[0] = CU1;
        cuHashes[1] = keccak256("cu3");
        vm.prank(user);
        vm.expectRevert(ITributeDraft.NotSameOwner.selector);
        td.mint(cuHashes);
    }

    function test_Revert_When_NotSameCurrency() public {
        // another CU for same user but with EUR currency
        bytes32 cuEur = keccak256("cu-eur");
        _submitCU(cuEur, user, "EUR", 1, 0, 0, 0, "kWh", new bytes32[](0));
        bytes32[] memory cuHashes = new bytes32[](2);
        cuHashes[0] = CU1;
        cuHashes[1] = cuEur;
        vm.prank(user);
        vm.expectRevert(ITributeDraft.NotSameCurrency.selector);
        td.mint(cuHashes);
    }

    function test_Revert_When_DuplicateCUInInputOrAcrossMints() public {
        // duplicate inside input
        bytes32[] memory dup = new bytes32[](2);
        dup[0] = CU1;
        dup[1] = CU1;
        vm.prank(user);
        vm.expectRevert(ITributeDraft.DuplicateId.selector);
        td.mint(dup);

        // mint once OK
        bytes32[] memory ok = new bytes32[](2);
        ok[0] = CU1;
        ok[1] = CU2;
        vm.prank(user);
        bytes32 tdId = td.mint(ok);
        assertTrue(td.get(tdId).submittedAt != 0);

        // reuse any of CU1 or CU2 afterwards should revert DuplicateId (consumptionUnitHashes)
        bytes32[] memory reuse = new bytes32[](1);
        reuse[0] = CU1;
        vm.prank(user);
        vm.expectRevert(ITributeDraft.DuplicateId.selector);
        td.mint(reuse);
    }
}
