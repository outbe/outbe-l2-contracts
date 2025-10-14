# [0001] Consumption Record on L2

# Status

Draft

# Version

0001 — Draft, Initial specification

# Context

A Consumption Record (CR) is a content-addressed, immutable registry entry that represents a single, verifiable
footprint of user consumption on L2. Each record is identified by a unique 32-byte hash (crHash) and is accompanied by
metadata describing the context of the record. Creation of records is permissioned to active Consumption Reflection
Agents (CRAs) via a CRA Registry.

This document describes the on-chain logic and data requirements for the L2 Consumption Record registry implemented by
the upgradeable smart contract ConsumptionRecordUpgradeable.

## Goals

- Provide a deterministic, append-only registry of consumption records keyed by crHash
- Enforce CRA-level access control for submission
- Support per-record metadata in flexible key/value format
- Support efficient batch submissions with single-timestamp semantics
- Remain upgradeable via UUPS with strict owner gating

## Non-Goals

- On-chain computation or verification of the record hash
- NFT minting/transfer semantics (the registry is not an ERC-721 token)
- ZK proof verification (can be added at the factory or L1 bridge layers later)

# Decision

We implement an L2 registry contract using Solidity with an upgradeable UUPS proxy pattern. Active CRAs submit records
that are stored by their content hash and linked to an owner address with arbitrary metadata. The registry exposes
querying by crHash and by owner. Batch submissions are supported with safety limits.

Key design choices:

- Access control is delegated to a CRA Registry and enforced by a CRAAware mixin via onlyActiveCRA.
- Record identity is externalized to a bytes32 hash supplied by submitters; the registry only enforces uniqueness and
  basic well-formedness.
- Upgradeability is handled by OpenZeppelin UUPSUpgradeable with owner-restricted upgrades.

# Architecture

```
Client (CRA) -> Proxy (UUPS) -> Implementation (ConsumptionRecordUpgradeable)
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

Contract: src/consumption_record/ConsumptionRecordUpgradeable.sol
Interface: src/interfaces/IConsumptionRecord.sol

ConsumptionRecordEntity:

```solidity
struct ConsumptionRecordEntity {
    bytes32 consumptionRecordId; // ID equals the submitted crHash
    address submittedBy;         // CRA address that submitted
    uint256 submittedAt;         // Block timestamp of submission
    address owner;               // Logical owner/principal of the record
    string[] metadataKeys;       // Keys for metadata entries (no empty strings)
    bytes32[] metadataValues;    // Values matched 1:1 with keys
}
```

# API

All functions are available on the proxy.

- initialize(address _craRegistry, address _owner)
    - One-time initializer. Sets CRA Registry and owner, initializes OZ upgradeable base contracts.
    - Requirements: non-zero addresses.

- submit(bytes32 crHash, address owner, string[] keys, bytes32[] values)
    - Only callable by an active CRA (onlyActiveCRA).
    - Creates a single record at current block.timestamp.
    - Validations:
        - crHash != 0x0
        - owner != address(0)
        - Record must not already exist
        - keys.length == values.length
        - No empty keys
    - Effects:
        - Persists ConsumptionRecordEntity
        - Appends crHash to ownerRecords[owner]
        - Increments total counter
    - Emits: Submitted(crHash, cra, timestamp)

- submitBatch(bytes32[] crHashes, address[] owners, string[][] keysArray, bytes32[][] valuesArray)
    - Only callable by an active CRA.
    - Creates multiple records using a single shared timestamp (captured once at the start).
    - Validations:
        - 0 < crHashes.length <= MAX_BATCH_SIZE (100)
        - owners.length == crHashes.length
        - keysArray.length == crHashes.length
        - valuesArray.length == crHashes.length
        - Per-item validations identical to submit()
    - Effects:
        - Repeats the single-record creation for each item
    - Emits: BatchSubmitted(batchSize, cra, timestamp)

- isExists(bytes32 crHash) -> bool
    - Returns whether a record exists.

- getConsumptionRecord(bytes32 crHash) -> ConsumptionRecordEntity
    - Returns the full record structure.

- getConsumptionRecordsByOwner(address owner) -> bytes32[]
    - Returns all record hashes associated with the owner.

- totalSupply() -> uint256
    - Returns total number of stored records (monotonic increment on submission).

- getOwner() -> address
    - Returns contract owner.

- supportsInterface(bytes4 interfaceId) -> bool
    - ERC165Compatible; currently delegates to super and can be extended.

# Events and Errors

Events (from IConsumptionRecord):

- Submitted(bytes32 indexed crHash, address indexed cra, uint256 timestamp)
- BatchSubmitted(uint256 indexed batchSize, address indexed cra, uint256 timestamp)

Errors (from IConsumptionRecord):

- AlreadyExists()
- InvalidHash()
- MetadataKeyValueMismatch()
- EmptyMetadataKey()
- InvalidOwner()
- BatchSizeTooLarge()
- EmptyBatch()

# Record Identity and Hashing

- crHash is a 32-byte identifier supplied by the caller (CRA). The contract treats it as an opaque identifier.
- Uniqueness is enforced at the storage layer: a record may not be resubmitted under the same crHash.
- The registry does not compute or verify crHash on-chain; upstream systems (e.g., aggregators, L1 bridges, or TEEs) can
  define deterministic hashing schemes.

# Access Control

- Only active CRAs may submit or batch submit records.
- Active status is queried via CRAAware against the CRA Registry.
- Admin/upgrade authority is the contract owner (OwnableUpgradeable).

# Upgradeability

- Pattern: UUPSUpgradeable
- Authorization: _authorizeUpgrade restricted to onlyOwner
- Initializer: initialize replaces constructor, constructor disables initializers on the implementation

# Storage and Gas Considerations

- Owner index: ownerRecords[owner] stores crHash list for direct lookups by owner.
- Metadata: stored as parallel arrays of keys and values to keep calldata ABI simple and fixed-width for values.
- Batch submission shares a single timestamp to reduce per-item gas and provide consistent ordering.
- MAX_BATCH_SIZE is capped at 100 to bound gas and storage operations per tx.

# Validation Rules Summary

On submit and per-item in submitBatch:

- crHash != 0x0 (InvalidHash)
- owner != address(0) (InvalidOwner)
- Record must not pre-exist (AlreadyExists)
- keys.length == values.length (MetadataKeyValueMismatch)
- All keys are non-empty strings (EmptyMetadataKey)

Batch-level:

- 0 < batchSize <= 100 (EmptyBatch, BatchSizeTooLarge)
- owners/keysArray/valuesArray lengths equal batchSize (MetadataKeyValueMismatch)

# Example Payloads

Single submission (pseudocode/ABI):

```
submit(
  crHash = 0x8b62...ff19,
  owner = 0xAbCDEF...1234,
  keys = ["worldwide_day", "settlement_currency"],
  values = [
    0x776f726c64776964655f646179000000000000000000000000000000000000, // bytes32-encoded string label or value
    0x7573640000000000000000000000000000000000000000000000000000000000  // "usd" as bytes32
  ]
)
```

Batch submission (two items):

```
submitBatch(
  crHashes = [0xAAA..., 0xBBB...],
  owners = [0x111..., 0x222...],
  keysArray = [ ["k1","k2"], ["k1"] ],
  valuesArray = [ [v11, v12], [v21] ]
)
```

# Integration Notes

- CRA Registry: The contract relies on CRA Registry to authorize CRAs. Deployments must ensure CRA registry is set and
  CRAs are onboarded/activated appropriately.
- Off-chain Indexing: Indexers can watch Submitted and BatchSubmitted to maintain rich views (e.g., owner -> record list
  with metadata unpacking).
- Tooling: The project ships Foundry scripts for deterministic deployments and upgrades.

# Security Considerations

- OnlyActiveCRA gate prevents unauthorized submissions; ensure CRA Registry correctness and governance.
- Metadata is unvalidated beyond shape; avoid storing sensitive information in plaintext. Use hashing or encryption
  off-chain if needed.
- Upgrade power is centralized to the owner; secure the owner key or use a timelock/multisig.
- Batch operations should consider reentrancy only if future hooks are added; current implementation is internal storage
  only.

# Related Changes

- None required for token/price oracles; the CR registry is currency-agnostic by design.
- Future enhancements can add pagination helpers for owner-based queries to improve dApp UX and reduce response sizes.

# Open Questions

- Should the registry enforce a canonical encoding for metadata values (e.g., keccak256 of UTF-8) to reduce ambiguity
  across submitters?
- Do we need pagination and filtering primitives on-chain for large owner datasets?
- Should we add optional signature-based submission by owners to complement CRA writes?
