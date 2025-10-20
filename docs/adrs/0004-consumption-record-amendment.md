# [0004] Consumption Record Amendment

# Status

Draft

# Version

0001 — Draft, Initial specification

# Context

A Consumption Record Amendment (CRAmd) is a content-addressed, immutable registry entry that represents a transaction
amendment to a previously reflected Act of Consumption. It mirrors the Consumption Record (CR) model but captures
post-factum adjustments such as corrections, chargebacks, partial refunds, or merchant-initiated changes. Each
amendment is identified off-chain by a Blake3-based preimage and is submitted on-chain by its 32-byte hash
(crAmendmentHash).

Creation of amendments is permissioned to active Consumption Reflection Agents (CRAs) via the CRA Registry.

This ADR documents the `ConsumptionRecordAmendmentUpgradeable` contract used to store amendment hashes and related
metadata. It is designed to be referenced by `ConsumptionUnitUpgradeable` during CU submissions.

## Goals

- Provide a deterministic, append-only registry of consumption record amendments keyed by crAmendmentHash
- Enforce CRA-level access control for submission
- Support per-amendment metadata in flexible key/value format
- Support efficient batching via multicall with bounded batch size
- Remain upgradeable via UUPS with strict owner gating

# Decision

We implement smart contract using Solidity with a UUPS upgradeable proxy pattern. Active CRAs submit
amendments identified by a bytes32 hash and accompanied by optional metadata. The registry exposes querying by
crAmendmentHash and by owner. Batched submissions are performed using a controlled multicall entrypoint.

Key design choices:
- Access control via CRAAware against the CRA Registry (onlyActiveCRA)
- Identity externalized to a bytes32 hash supplied by submitters; the registry enforces uniqueness and well-formedness
- Upgradeability via OpenZeppelin UUPSUpgradeable with owner-restricted upgrades

# Architecture

```
Client (CRA) -> Proxy (UUPS) -> Implementation (ConsumptionRecordAmendmentUpgradeable)
                     |                 ^
                     v                 |
               Storage (Proxy)     Upgrades (Owner)
```

Dependencies:
- CRAAware (CRA Registry checks)
- OwnableUpgradeable (upgrade/admin ops)
- UUPSUpgradeable (upgrade mechanism)
- ERC165Upgradeable (introspection)
- MulticallUpgradeable (batched submissions)

# Core Data Structures

Contract: src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol
Interface: src/interfaces/IConsumptionRecordAmendment.sol

ConsumptionRecordAmendmentEntity:

```solidity
struct ConsumptionRecordAmendmentEntity {
    bytes32 consumptionRecordAmendmentId; // equals submitted crAmendmentHash
    address submittedBy;                  // CRA address
    uint256 submittedAt;                  // block.timestamp of submission
    address owner;                        // logical owner/principal
    string[] metadataKeys;                // non-empty keys
    bytes32[] metadataValues;             // 1:1 with keys
}
```

# API

All functions are available on the proxy.

- initialize(address _craRegistry, address _owner)
    - One-time initializer. Sets CRA Registry and owner; initializes OZ base contracts.
    - Requirements: non-zero addresses.

- submit(bytes32 crAmendmentHash, address owner, string[] keys, bytes32[] values)
    - Only callable by an active CRA (onlyActiveCRA).
    - Creates a single amendment at current block.timestamp.
    - Validations:
        - crAmendmentHash != 0x0
        - owner != address(0)
        - Record must not already exist
        - keys.length == values.length
        - No empty keys
    - Effects:
        - Persists ConsumptionRecordAmendmentEntity
        - Appends crAmendmentHash to owner index
        - Increments total counter
    - Emits: Submitted(crAmendmentHash, cra, timestamp)

- multicall(bytes[] data) -> bytes[] results
    - Only callable by an active CRA.
    - Allows multiple submit(...) calls in a single transaction, each encoded as calldata and delegated internally.
    - Validations:
        - 0 < data.length <= MAX_BATCH_SIZE (100)
        - Each entry must be a call to submit(...) (otherwise reverts InvalidCall)
    - Effects:
        - Executes each submit with shared access control and pause checks; each inner call emits its own Submitted event.
    - Reverts: EmptyBatch, BatchSizeTooLarge, InvalidCall

- isExists(bytes32 crAmendmentHash) -> bool
    - Returns whether an amendment exists.

- getConsumptionRecordAmendment(bytes32 crAmendmentHash) -> ConsumptionRecordAmendmentEntity
    - Returns the full amendment structure.

- getConsumptionRecordAmendmentsByOwner(address owner) -> bytes32[]
    - Returns all amendment hashes associated with the owner.

# Events and Errors

Events (from IConsumptionRecordAmendment):
- Submitted(bytes32 indexed crAmendmentHash, address indexed cra, uint256 timestamp)

Errors (from IConsumptionRecordAmendment):
- AlreadyExists()
- InvalidHash()
- MetadataKeyValueMismatch()
- EmptyMetadataKey()
- InvalidOwner()
- BatchSizeTooLarge()
- EmptyBatch()
- InvalidCall()

# Record Identity and Hashing

- crAmendmentHash is a 32-byte identifier supplied by the caller (CRA). The contract treats it as an opaque identifier.
- Uniqueness is enforced at the storage layer: an amendment may not be resubmitted under the same hash.
- The registry does not compute or verify the hash preimage on-chain; upstream systems define deterministic hashing schemes.

# Access Control

- Only active CRAs may submit or multicall. Enforced by CRAAware against the CRA Registry.
- Admin/upgrade authority is the contract owner (OwnableUpgradeable).

# Upgradeability

- Pattern: UUPSUpgradeable
- Authorization: _authorizeUpgrade restricted to onlyOwner
- Initializer: initialize replaces constructor; implementation constructor disables further initializers

# Integration with ConsumptionUnitUpgradeable

- CUs may link amendment hashes in addition to base CR hashes. The CU contract enforces global uniqueness for both
  sets and rejects overlapping hashes within the same submission.
- CRA workflows should include any applicable amendment hashes when submitting CUs for a Worldwide Day to provide
  accurate settlement and provenance.

# Validation Rules Summary

On submit and per-item in multicall:
- crAmendmentHash != 0x0 (InvalidHash)
- owner != address(0) (InvalidOwner)
- Amendment must not pre-exist (AlreadyExists)
- keys.length == values.length (MetadataKeyValueMismatch)
- All keys are non-empty strings (EmptyMetadataKey)

Batch-level (multicall):
- 0 < batchSize <= 100 (EmptyBatch, BatchSizeTooLarge)
- Each entry must target submit(...) (InvalidCall)
