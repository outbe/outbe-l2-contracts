# [0002] Consumption Unit on L2

# Status

Draft

# Version

0001 — Draft, Initial specification

# Context

A Consumption Unit (CU) is an immutable, content-addressed entry representing a normalized unit of user consumption on
L2. Each CU is identified by a unique 32-byte hash (cuHash) and contains settlement information, the worldwide day, and
a list of linked consumption record (CR) hashes providing provenance and breakdown. Creation is permissioned to active
Consumption Reflection Agents (CRAs) via the CRA Registry.

This document describes the on-chain logic and data requirements for the L2 Consumption Unit registry implemented by the
upgradeable smart contract ConsumptionUnitUpgradeable.

## Goals

- Deterministic, append-only registry of consumption units keyed by cuHash
- Enforce CRA-level access control for submission
- Capture settlement amounts and worldwide day in a compact form
- Reference one or more ConsumptionRecord hashes with global uniqueness per CR hash
- Support efficient batch submissions with single-timestamp semantics
- Remain upgradeable via UUPS with strict owner gating

## Non-Goals

- On-chain computation/verification of cuHash or source CR hashes
- NFT transfer semantics (the registry is not ERC-721 though it reports totalSupply akin to a soulbound index)
- ZK proof verification (can be added at factory/bridge layers)

# Decision

We implement an L2 registry contract using Solidity and the UUPS upgradeable proxy pattern. Active CRAs submit CUs that
are stored by content hash, associated to an owner, and carry settlement context. A CU references zero or more CR
hashes, each enforced to be globally unique across all CU submissions to prevent double-linking.

Key design choices:

- Access control delegated to the CRA Registry via CRAAware and enforced by onlyActiveCRA.
- Identity is externalized to a bytes32 cuHash supplied by submitters; the registry enforces uniqueness and
  well-formedness.
- Global uniqueness for each linked CR hash to prevent the same CR being attached to multiple CUs.
- Upgradeability is handled by OpenZeppelin UUPSUpgradeable with owner-restricted upgrades.

# Architecture

```
Client (CRA) -> Proxy (UUPS) -> Implementation (ConsumptionUnitUpgradeable)
                     |                 ^
                     v                 |
               Storage (Proxy)     Upgrades (Owner)
```

Dependencies:

- CRAAware (uses CRA Registry to check if msg.sender is an active CRA)
- OwnableUpgradeable (upgrade authority, admin ops)
- UUPSUpgradeable (upgrade mechanism)
- ERC165Upgradeable (introspection)

# Core Data Structures

Contract: src/consumption_unit/ConsumptionUnitUpgradeable.sol
Interface: src/interfaces/IConsumptionUnit.sol

ConsumptionUnitEntity:

```solidity
struct ConsumptionUnitEntity {
    bytes32 consumptionUnitId;   // ID equals the submitted cuHash
    address owner;               // Logical owner/principal of the CU
    address submittedBy;         // CRA address that submitted
    uint256 submittedAt;         // Block timestamp of submission
    uint32 worldwideDay;         // ISO-8601 compact form, e.g., 20250923
    uint256 settlementAmountBase;// Amount in base (natural) units, >= 0
    uint256 settlementAmountAtto;// Amount in fractional 1e-18 units, 0 <= x < 1e18
    uint16 settlementCurrency;   // ISO-4217 numeric code, non-zero
    bytes32[] crHashes;          // Linked CR hashes; each must be unique globally
}
```

# API

All functions are available on the proxy.

- initialize(address _craRegistry, address _owner)
    - One-time initializer. Sets CRA Registry and owner; initializes OZ components.
    - Requirements: non-zero addresses.

- submit(
  bytes32 cuHash,
  address owner,
  uint16 settlementCurrency,
  uint32 worldwideDay,
  uint128 settlementBaseAmount,
  uint128 settlementAttoAmount,
  bytes32[] hashes
  ) external onlyActiveCRA
    - Creates a single CU at current block.timestamp.
    - Validations (see Validation Rules): cuHash non-zero and unique, owner non-zero, currency non-zero, amounts shape
      valid, CR hashes not previously used.
    - Effects: persists entity, indexes by owner, increments total counter.
    - Emits: Submitted(cuHash, cra, timestamp)

- submitBatch(
  bytes32[] cuHashes,
  address[] owners,
  uint32[] worldwideDays,
  uint16[] settlementCurrencies,
  uint256[] settlementAmountsBase,
  uint256[] settlementAmountsAtto,
  bytes32[][] crHashesArray
  ) external onlyActiveCRA
    - Creates multiple CUs using a single shared timestamp (captured once at the start).
    - Validations: 0 < batchSize <= MAX_BATCH_SIZE (100); arrays lengths match; per-item validations identical to
      submit().
    - Effects: repeats single CU creation for each item.
    - Emits: BatchSubmitted(batchSize, cra, timestamp)

- isExists(bytes32 cuHash) -> bool
    - Returns whether a CU exists.

- getConsumptionUnit(bytes32 cuHash) -> ConsumptionUnitEntity
    - Returns the full CU structure.

- getConsumptionUnitsByOwner(address owner) -> bytes32[]
    - Returns all CU hashes associated with the owner.

- totalSupply() -> uint256
    - Returns total number of CU records stored.

- getOwner() -> address
    - Returns contract owner.

- supportsInterface(bytes4 interfaceId) -> bool
    - ERC165-compatible; currently delegates to super and can be extended later.

# Events and Errors

Events (from IConsumptionUnit):

- Submitted(bytes32 indexed cuHash, address indexed cra, uint256 timestamp)
- BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp)

Errors (from IConsumptionUnit):

- AlreadyExists()
- ConsumptionRecordAlreadyExists()  // a linked CR hash was already used elsewhere
- InvalidHash()
- InvalidOwner()
- EmptyBatch()
- BatchSizeTooLarge()
- InvalidSettlementCurrency()
- InvalidAmount()                   // either both amounts are zero or atto >= 1e18
- ArrayLengthMismatch()

# Record Identity and Referencing

- cuHash is a 32-byte identifier supplied by the caller (CRA). The contract treats it as an opaque identifier.
- Uniqueness is enforced per CU: the same cuHash cannot be reused.
- Each referenced CR hash (crHashes[i]) must be unique globally across all CUs. The contract tracks this in
  consumptionRecordHashes to prevent double-linking.
- The registry does not compute or verify cuHash or crHashes on-chain; upstream systems define their hashing schemes.

# Access Control

- Only active CRAs may submit or batch submit. Enforced by CRAAware against the CRA Registry.
- Admin/upgrade authority is the contract owner (OwnableUpgradeable).

# Upgradeability

- Pattern: UUPSUpgradeable
- Authorization: _authorizeUpgrade restricted to onlyOwner
- Initializer: initialize replaces constructor; implementation constructor disables further initializers

# Storage and Gas Considerations

- Owner index: ownerRecords[owner] stores CU hashes for direct lookups by owner.
- Settlement and amounts are stored in fixed-width integers (uint16 currency, uint32 day, uint256 amounts) for clarity
  and extensibility.
- Amount validation ensures at least one of base/atto is non-zero and atto < 1e18.
- Batch submission shares a single timestamp to reduce per-item gas and ensure consistent ordering.
- MAX_BATCH_SIZE is capped at 100 to bound gas/storage per tx.

# Validation Rules Summary

On submit and per-item in submitBatch:

- cuHash != 0x0 (InvalidHash)
- owner != address(0) (InvalidOwner)
- CU must not pre-exist (AlreadyExists)
- settlementCurrency != 0 (InvalidSettlementCurrency)
- Amounts: not both zero AND atto < 1e18 (InvalidAmount)
- Each crHash must not have been used before (ConsumptionRecordAlreadyExists)

Batch-level:

- 0 < batchSize <= 100 (EmptyBatch, BatchSizeTooLarge)
- All arrays have length == batchSize (ArrayLengthMismatch)

# Example Payloads

Single submission (pseudocode/ABI):

```
submit(
  cuHash = 0x99ab...fe01,
  owner = 0xAbCDEF...1234,
  settlementCurrency = 840,       // USD (ISO-4217 numeric)
  worldwideDay = 20250701,        // YYYYMMDD as uint32
  settlementBaseAmount = 48,
  settlementAttoAmount = 700000000000000000, // 0.7 in 1e-18
  hashes = [0xc42433...79b4]      // linked CR hashes
)
```

Batch submission (two items):

```
submitBatch(
  cuHashes = [0xAAA..., 0xBBB...],
  owners = [0x111..., 0x222...],
  worldwideDays = [20250701, 20250702],
  settlementCurrencies = [840, 978],
  settlementAmountsBase = [48, 97],
  settlementAmountsAtto = [700000000000000000, 400000000000000000],
  crHashesArray = [ [0xc42433...79b4], [0xdeadbe...ef01] ]
)
```

# Integration Notes

- CRA Registry: Ensure CRA registry is configured and CRAs onboarded/activated before allowing submissions.
- Consumption Record linkage: The contract enforces global uniqueness of linked CR hashes but does not verify their
  existence or ownership yet (see TODO in implementation). Upstream services should ensure CRs exist and correspond to
  the same owner.
- Tribute Draft integration: Other modules (e.g., TributeDraftUpgradeable) may aggregate CUs by owner/day; consistency
  of worldwideDay and currency is recommended for predictable roll-ups.

# Security Considerations

- onlyActiveCRA gate protects against unauthorized writes; secure CRA Registry governance.
- Global uniqueness of CR hashes mitigates double-counting across multiple CU entries.
- Metadata is minimal; settlement values are immutable after submission.
- Upgrade power is centralized to the owner; consider timelock/multisig ownership.
- Reentrancy is not present as the contract performs internal storage-only writes and emits events; review if future
  external calls are added.

# Related Changes

- None required for token/price oracles; CU registry stores raw settlement values and currency codes.
- Future enhancement: add optional verification that each referenced CR exists and belongs to the same owner/day.

# Open Questions

- Should we enforce that all linked CR hashes belong to the same owner and worldwide day as the CU?
- Should we standardize currency to ISO-4217 numeric only, or support alphas where appropriate?
- Do we need pagination helpers for owner-based queries for large datasets?
