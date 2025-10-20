# [0003] Tribute Draft

# Status

Draft

# Version

0001 — Draft, Initial specification

# Context

A Tribute Draft (TD) is an immutable, content-addressed aggregate built from multiple Consumption Units (CUs) for a
single owner and worldwide day. Tribute Drafts provide a user-facing, pre-tribute artifact that summarizes the
settlement amounts for the selected day and currency, while preserving provenance via linked CU hashes.

This document describes the on-chain logic and data requirements for the Tribute Draft registry implemented by the
upgradeable smart contract `TributeDraftUpgradeable`.

## Goals

- Allow end users to mint a Tribute Draft by aggregating their Consumption Units
- Enforce strict aggregation rules: same owner, same worldwide day, same settlement currency
- Ensure each CU hash is used at most once across all Tribute Drafts (double-spend prevention)
- Provide deterministic TD identity derived from inputs
- Remain upgradeable via UUPS with owner-only upgrades

# Decision

We implement smart contract using Solidity with the UUPS upgradeable proxy pattern. Any user can submit a
set of CU hashes owned by them for a specific day and currency. The contract validates aggregation invariants, performs
amount summation with carry between base and atto components, assigns a deterministic TD identifier, and records the
aggregate in storage. Each referenced CU hash is globally marked as used to prevent re-aggregation elsewhere.

Key design choices:

- Open minting by users, with on-chain checks to ensure all referenced CUs exist and belong to the caller.
- Identity is derived as keccak256(owner, worldwideDay, cuHashes), keeping the identifier deterministic for a given
  aggregation input.
- Global uniqueness for each referenced CU hash to prevent double-use across multiple TDs.
- Upgradeability via OpenZeppelin UUPSUpgradeable with onlyOwner upgrade authorization.

# Architecture

```
User (Owner) -> Proxy (UUPS) -> Implementation (TributeDraftUpgradeable)
                    |                 ^
                    v                 |
              Storage (Proxy)     Upgrades (Owner)
```

Dependencies:

- IConsumptionUnit (to fetch CU records by hash)
- OwnableUpgradeable (admin/upgrade control)
- UUPSUpgradeable (upgrade mechanism)
- ERC165Upgradeable (introspection)

# Core Data Structures

Contract: src/tribute_draft/TributeDraftUpgradeable.sol
Interface: src/interfaces/ITributeDraft.sol

TributeDraftEntity:

```solidity
struct TributeDraftEntity {
    bytes32 tributeDraftId;      // Deterministic ID of this draft (derived on submit)
    address owner;               // Owner of all aggregated CUs
    uint16 settlementCurrency;   // ISO-4217 numeric code (non-zero)
    uint32 worldwideDay;         // ISO-8601 compact form, e.g., 20250923
    uint256 settlementAmountBase;// Aggregated base amount (>= 0)
    uint256 settlementAmountAtto;// Aggregated fractional amount (0 <= x < 1e18)
    bytes32[] cuHashes;          // Linked CU hashes
    uint256 submittedAt;         // Block timestamp when minted
}
```

# API

All functions are available on the proxy.

- initialize(address consumptionUnit)
    - One-time initializer. Sets the ConsumptionUnit contract address and initializes OZ components.
    - Requirements: consumptionUnit != address(0)

- submit(bytes32[] cuHashes) -> bytes32 tdId
    - Anyone can call. Mints a Tribute Draft from the provided CU hashes.
    - Validations:
        - cuHashes is non-empty and contains no duplicates
        - Each cuHash was not used previously in any Tribute Draft
        - For each cuHash: CU exists in ConsumptionUnit
        - All CUs share the same owner, currency, and worldwide day
    - Effects:
        - Aggregates amounts: base + atto with carry (attoSum >= 1e18 increases base)
        - Computes tdId = keccak256(abi.encode(owner, worldwideDay, cuHashes))
        - Persists TributeDraftEntity under tdId
        - Marks each cuHash as used
        - Increments total counter
    - Emits: Submitted(tdId, owner, submittedBy, cuCount, timestamp)

- getTributeDraft(bytes32 tdId) -> TributeDraftEntity
    - Returns the full Tribute Draft record by id.

- getConsumptionUnitAddress() -> address
    - Returns the address of the linked ConsumptionUnit contract.

- setConsumptionUnitAddress(address)
    - onlyOwner. Updates the linked ConsumptionUnit address.

- totalSupply() -> uint256
    - Returns total number of Tribute Drafts minted.

- supportsInterface(bytes4 interfaceId) -> bool
    - ERC165-compatible; currently delegates to super and can be extended.

# Events and Errors

Events (from ITributeDraft):

- Submitted(bytes32 indexed tdId, address indexed owner, address indexed submittedBy, uint256 cuCount, uint256
  timestamp)

Errors (from ITributeDraft):

- EmptyArray()
- AlreadyExists()                  // duplicate CU in input or CU already used by any TD
- NotFound(bytes32 cuHash)         // referenced CU not found
- NotSameOwner(bytes32 cuHash)     // CU owner differs from the first CU owner/caller
- NotSettlementCurrencyCurrency()  // settlement currency mismatch
- NotSameWorldwideDay()            // worldwide day mismatch

# Aggregation, Identity, and Hashing

- Identity: tdId is computed as keccak256(abi.encode(owner, worldwideDay, cuHashes)).
- The contract treats cuHashes as opaque identifiers; it verifies existence via IConsumptionUnit.getConsumptionUnit.
- Each cuHash is placed into a global set consumptionUnitHashes to ensure it is used at most once across all TDs.
- Amounts are aggregated via base+atto with carry such that atto stays in [0, 1e18).

# Access Control

- submit is permissionless for the owner of the referenced CUs; checks ensure the caller is the same as CU owner.
- Admin/upgrade operations are restricted to the contract owner (OwnableUpgradeable), including
  setConsumptionUnitAddress and upgrades.

# Upgradeability

- Pattern: UUPSUpgradeable
- Authorization: _authorizeUpgrade restricted to onlyOwner
- Initializer: initialize replaces constructor; implementation constructor disables further initializers

# Storage and Gas Considerations

- Used CU set: consumptionUnitHashes enforces one-time CU usage; O(n) marking per submit.
- TD index: mapping(bytes32 => TributeDraftEntity) stores complete entries for direct retrieval by id.
- Aggregation uses a single pass across inputs; a nested pass checks for duplicates within the provided array.
- No batch function is required since submit accepts an arbitrary number of CUs in one call.

# Validation Rules Summary

On submit:

- cuHashes.length > 0 (EmptyArray)
- Input contains no duplicate cuHashes (AlreadyExists)
- Each cuHash has not been used previously in any TD (AlreadyExists)
- First CU must exist (NotFound) and caller must equal first.owner (NotSameOwner)
- For every subsequent CU:
    - CU exists (NotFound)
    - CU.owner == first.owner (NotSameOwner)
    - CU.settlementCurrency == first.settlementCurrency (NotSettlementCurrencyCurrency)
    - CU.worldwideDay == first.worldwideDay (NotSameWorldwideDay)

# Integration Notes

- Consumption Unit linkage: The contract relies on an external ConsumptionUnit registry. Ensure the address is set
  correctly during deployment and can be updated by the owner if needed.
- Indexing: Indexers can watch Submitted to maintain lists of TDs per owner and reconstruct aggregation inputs from
  cuHashes.

# Security Considerations

- Only the CU owner can aggregate into a TD; this is enforced by ownership checks against the first CU, then validated
  across all referenced CUs.
- Global uniqueness of CU hashes prevents double-counting and reuse across TDs.
- Upgrade authority is centralized; consider assigning a timelock/multisig as owner.
- No external calls are made beyond reading from the Consumption Unit contract, minimizing reentrancy risk.
