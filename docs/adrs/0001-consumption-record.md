# [0001] Consumption Record

# Status

Draft

# Version

0001 — Draft, Initial specification

# Context

A Consumption Record (CR) is a content-addressed, immutable registry entry that represents a single, verifiable
footprint of a user's Act of Consumption.

Operational context from the reflection:

- CRA ingests transactions twice per Worldwide Day (split by local time): after local day end, and after Worldwide Day
  end (23:59 UTC–12).
- CRA filters eligible merchant transactions, normalizes them to the CR schema, computes settlement values in Settlement
  Currency and coen, and generates the cryptographic hash per record.
- Refunds are represented as amendment CRs recorded in subsequent periods with references to the original CU and
  Worldwide Day.
- Deduplication is enforced network-wide by ensuring CR hashes are unique across all CUs.

Creation of records is permissioned to active Consumption Reflection Agents (CRAs) via a CRA Registry.

This document describes the on-chain logic and data requirements for the L2 Consumption Record registry implemented by
the upgradeable smart contract `ConsumptionRecordUpgradeable`.

## Goals

- Provide a deterministic, append-only registry of consumption records keyed by `crHash`
- Enforce CRA-level access control for submission
- Support per-record metadata in a flexible key / value format
- Support efficient batch submissions with single-timestamp semantics

# Decision

We implement smart contract using Solidity with an upgradeable proxy pattern. Active CRAs submit records
that are stored by their content hash and linked to an owner address with arbitrary metadata. The registry exposes
querying by crHash and by owner. Batch submissions are supported by a mutlicall pattern with safety limits.

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
- MulticallUpgradeable (batched submissions)

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

- multicall(bytes[] data) -> bytes[] results
    - Only callable by an active CRA.
    - Allows multiple submit(...) calls in a single transaction, each encoded as calldata and delegated internally.
    - Validations:
        - 0 < data.length <= MAX_BATCH_SIZE (100)
        - Each entry must be a call to submit(...) (otherwise reverts InvalidCall)
    - Effects:
        - Executes each submit with shared access control and pause checks; each inner call emits its own Submitted
          event.
    - Reverts: EmptyBatch, BatchSizeTooLarge, InvalidCall

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

Errors (from IConsumptionRecord):

- AlreadyExists()
- InvalidHash()
- MetadataKeyValueMismatch()
- EmptyMetadataKey()
- InvalidOwner()
- BatchSizeTooLarge()
- EmptyBatch()
- InvalidCall()

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
