// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ConsumptionUnitUpgradeable} from "../../src/consumption_unit/ConsumptionUnitUpgradeable.sol";
import {CRARegistryUpgradeable} from "../../src/cra_registry/CRARegistryUpgradeable.sol";
import {ICRARegistry} from "../../src/interfaces/ICRARegistry.sol";
import {IConsumptionUnit} from "../../src/interfaces/IConsumptionUnit.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ConsumptionUnitUpgradeableTest is Test {
    ConsumptionUnitUpgradeable public cuContract;
    CRARegistryUpgradeable public registry;

    ConsumptionUnitUpgradeable public cuImplementation;
    CRARegistryUpgradeable public registryImplementation;

    ERC1967Proxy public cuProxy;
    ERC1967Proxy public registryProxy;

    address public owner;
    address public cra1;
    address public cra2;
    address public unauthorized;
    address public recordOwner1;
    address public recordOwner2;

    bytes32 public constant CU_HASH_1 = keccak256("cu_hash_1");
    bytes32 public constant CU_HASH_2 = keccak256("cu_hash_2");
    bytes32 public constant ZERO_HASH = bytes32(0);

    event Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp);
    event BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp);

    function setUp() public {
        owner = address(this);
        cra1 = makeAddr("cra1");
        cra2 = makeAddr("cra2");
        unauthorized = makeAddr("unauthorized");
        recordOwner1 = makeAddr("recordOwner1");
        recordOwner2 = makeAddr("recordOwner2");

        // Deploy CRA Registry
        registryImplementation = new CRARegistryUpgradeable();
        bytes memory registryInitData = abi.encodeWithSignature("initialize(address)", owner);
        registryProxy = new ERC1967Proxy(address(registryImplementation), registryInitData);
        registry = CRARegistryUpgradeable(address(registryProxy));

        // Deploy Consumption Unit
        cuImplementation = new ConsumptionUnitUpgradeable();
        bytes memory cuInitData = abi.encodeWithSignature("initialize(address,address)", address(registry), owner);
        cuProxy = new ERC1967Proxy(address(cuImplementation), cuInitData);
        cuContract = ConsumptionUnitUpgradeable(address(cuProxy));

        // Register CRAs
        registry.registerCra(cra1, "CRA One");
        registry.registerCra(cra2, "CRA Two");
    }

    function test_InitialState() public view {
        assertEq(cuContract.getOwner(), owner);
        assertEq(cuContract.getCraRegistry(), address(registry));
        assertFalse(cuContract.isExists(CU_HASH_1));
        assertEq(cuContract.VERSION(), "1.0.0");
        assertEq(cuContract.MAX_BATCH_SIZE(), 100);
    }

    function test_Initialize_RevertWhen_ZeroRegistry() public {
        ConsumptionUnitUpgradeable newImpl = new ConsumptionUnitUpgradeable();

        bytes memory initData = abi.encodeWithSignature("initialize(address,address)", address(0), owner);

        vm.expectRevert("CRA Registry cannot be zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertWhen_ZeroOwner() public {
        ConsumptionUnitUpgradeable newImpl = new ConsumptionUnitUpgradeable();

        bytes memory initData = abi.encodeWithSignature("initialize(address,address)", address(registry), address(0));

        vm.expectRevert("Owner cannot be zero address");
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Submit_Basic() public {
        string memory settlementCurrency = "USD";
        uint64 settlementBaseAmount = 123;
        uint128 settlementAttoAmount = 45;
        uint64 nominalBaseQty = 10;
        uint128 nominalAttoQty = 1;
        string memory nominalCurrency = "kWh";
        string[] memory hashes = new string[](2);
        hashes[0] = "hashA";
        hashes[1] = "hashB";

        vm.expectEmit(true, true, false, true);
        emit Submitted(CU_HASH_1, cra1, block.timestamp);

        vm.prank(cra1);
        cuContract.submit(
            CU_HASH_1,
            recordOwner1,
            settlementCurrency,
            settlementBaseAmount,
            settlementAttoAmount,
            nominalBaseQty,
            nominalAttoQty,
            nominalCurrency,
            hashes
        );

        assertTrue(cuContract.isExists(CU_HASH_1));

        IConsumptionUnit.CuRecord memory record = cuContract.getRecord(CU_HASH_1);
        assertEq(record.submittedBy, cra1);
        assertEq(record.owner, recordOwner1);
        assertEq(record.settlementCurrency, settlementCurrency);
        assertEq(record.settlementBaseAmount, settlementBaseAmount);
        assertEq(record.settlementAttoAmount, settlementAttoAmount);
        assertEq(record.nominalBaseQty, nominalBaseQty);
        assertEq(record.nominalAttoQty, nominalAttoQty);
        assertEq(record.nominalCurrency, nominalCurrency);
        assertEq(record.hashes.length, 2);
        assertEq(record.hashes[0], "hashA");
        assertEq(record.submittedAt, block.timestamp);

        bytes32[] memory ownerRecords = cuContract.getRecordsByOwner(recordOwner1);
        assertEq(ownerRecords.length, 1);
        assertEq(ownerRecords[0], CU_HASH_1);
    }

    function test_SubmitBatch() public {
        bytes32[] memory hashes = new bytes32[](2);
        address[] memory owners = new address[](2);
        string[] memory settlementCurrencies = new string[](2);
        uint64[] memory settlementBaseAmounts = new uint64[](2);
        uint128[] memory settlementAttoAmounts = new uint128[](2);
        uint64[] memory nominalBaseQtys = new uint64[](2);
        uint128[] memory nominalAttoQtys = new uint128[](2);
        string[] memory nominalCurrencies = new string[](2);
        string[][] memory hashesArray = new string[][](2);

        hashes[0] = CU_HASH_1;
        hashes[1] = CU_HASH_2;
        owners[0] = recordOwner1;
        owners[1] = recordOwner2;
        settlementCurrencies[0] = "USD";
        settlementCurrencies[1] = "EUR";
        settlementBaseAmounts[0] = 100;
        settlementBaseAmounts[1] = 200;
        settlementAttoAmounts[0] = 10;
        settlementAttoAmounts[1] = 20;
        nominalBaseQtys[0] = 5;
        nominalBaseQtys[1] = 6;
        nominalAttoQtys[0] = 0;
        nominalAttoQtys[1] = 1;
        nominalCurrencies[0] = "kWh";
        nominalCurrencies[1] = "kWh";
        hashesArray[0] = new string[](1);
        hashesArray[0][0] = "h1";
        hashesArray[1] = new string[](0);

        vm.expectEmit(true, true, false, true);
        emit BatchSubmitted(2, cra1, block.timestamp);

        vm.prank(cra1);
        cuContract.submitBatch(
            hashes,
            owners,
            settlementCurrencies,
            settlementBaseAmounts,
            settlementAttoAmounts,
            nominalBaseQtys,
            nominalAttoQtys,
            nominalCurrencies,
            hashesArray
        );

        assertTrue(cuContract.isExists(CU_HASH_1));
        assertTrue(cuContract.isExists(CU_HASH_2));
    }

    function test_Reverts() public {
        string[] memory emptyHashes = new string[](0);

        // not active CRA
        vm.prank(unauthorized);
        vm.expectRevert(IConsumptionUnit.CRANotActive.selector);
        cuContract.submit(CU_HASH_1, recordOwner1, "USD", 0, 0, 0, 0, "kWh", emptyHashes);

        // zero hash
        vm.prank(cra1);
        vm.expectRevert(IConsumptionUnit.InvalidHash.selector);
        cuContract.submit(ZERO_HASH, recordOwner1, "USD", 0, 0, 0, 0, "kWh", emptyHashes);

        // zero owner
        vm.prank(cra1);
        vm.expectRevert(IConsumptionUnit.InvalidOwner.selector);
        cuContract.submit(CU_HASH_1, address(0), "USD", 0, 0, 0, 0, "kWh", emptyHashes);

        // empty currency
        vm.prank(cra1);
        vm.expectRevert(IConsumptionUnit.InvalidCurrency.selector);
        cuContract.submit(CU_HASH_1, recordOwner1, "", 0, 0, 0, 0, "kWh", emptyHashes);

        // invalid atto boundary (>= 1e18)
        vm.prank(cra1);
        vm.expectRevert(IConsumptionUnit.InvalidAmount.selector);
        cuContract.submit(CU_HASH_1, recordOwner1, "USD", 0, 1e18, 0, 0, "kWh", emptyHashes);
    }
}
