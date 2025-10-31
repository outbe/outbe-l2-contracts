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

- Compatibility with `ERC721Enumerable` standard
- Access control via CRAAware against the CRA Registry (onlyActiveCRA)
- Identity externalized to a uint256 hash supplied by submitters; the registry enforces uniqueness and well-formedness
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

# Record Identity and Hashing

Consumption Amendment Records are identified by an Id which is a 32-byte hash.
The hash is derived from the following attributes and submitted by CRA in hashed form to L2:

- `bank_account_hash` - User's Account details hash `hash(bic + iban or bban)`.
- `registered_at` - Time when the financial institution registered the transaction, time precision seconds, timezone strictly UTC, ISO 8601.

Such hash is computed by the CRA and stored in the `uint256 crId` field. It is used to identify the record and to ensure uniqueness.
The contract treats it as an opaque identifier.

# Core Data Structures

Contract: src/consumption_record/ConsumptionRecordAmendmentUpgradeable.sol
Interface: src/interfaces/IConsumptionRecordAmendment.sol

ConsumptionRecordAmendmentEntity:

```solidity
struct ConsumptionRecordAmendmentEntity {
    /// @notice consumption record hash id
    uint256 crId;
    /// @notice Address of the CRA that submitted this record
    address submittedBy;
    /// @notice Timestamp when the record was submitted
    uint256 submittedAt;
    /// @notice Address of the owner of this consumption record
    address owner;
    /// @notice Array of metadata keys
    string[] metadataKeys;
    /// @notice Array of metadata values (matches keys array)
    bytes32[] metadataValues;
}
```

# API

All functions are available on the proxy.

- initialize(address _craRegistry, address _owner)
    - One-time initializer. Sets CRA Registry and owner; initializes OZ base contracts.
    - Requirements: non-zero addresses.

- submit(uint256 crId, address tokenOwner, string[] memory keys, bytes32[] memory values)
    - Only callable by an active CRA (onlyActiveCRA).
    - Creates a single amendment at current block.timestamp.
    - Validations:
        - crId should be a valid hash
        - owner != address(0)
        - Record must not already exist
        - keys.length == values.length
        - No empty keys
    - Effects:
        - Persists ConsumptionRecordAmendmentEntity
        - Appends crId to owner index
        - Increments total counter
    - Emits: Minted(cra, tokenOwner, crId)

- multicall(bytes[] data) -> bytes[] results
    - Allows multiple submit(...) calls in a single transaction, each encoded as calldata and delegated internally.
    - Effects:
        - Executes each submit with shared access control and pause checks; each inner call emits its own Submitted event.

- exists(uint256 crId) -> bool
    - Returns whether an amendment record exists.

- getData(uint256 crId) -> ConsumptionRecordAmendmentEntity
    - Returns the full amendment record structure.

- balanceOf(address owner) -> uint256
    - Returns a number of tokens owned by the given address.
-
- tokenOfOwnerByIndex(address owner, uint256 index) -> uint256
    - Returns the crId at the given index for the owner.

- totalSupply() -> uint256
    - Returns total number of stored tokens (monotonic increment on submission).

- owner() -> address
    - Returns contract owner.

- supportsInterface(bytes4 interfaceId) -> bool
    - ERC165Compatible; currently delegates to super and can be extended.

# Events and Errors

Events (from IConsumptionRecordAmendment):

- Minted(address indexed minter, address indexed to, uint256 indexed crId)

Errors (from IConsumptionRecordAmendment):

- AlreadyExists()
- InvalidTokenId()
- InvalidMetadata(string reason)

# Access Control

- Only active CRAs may submit or batch submit records.
- Active status is queried via CRAAware against the CRA Registry.
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

On submit:

- crId validated to have a non-zero hash (InvalidTokenId)
- owner != address(0) (InvalidOwner)
- Record must not pre-exist (AlreadyExists)
- keys.length == values.length (InvalidMetadata)
- All keys are non-empty strings (InvalidMetadata)
