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

- Compatibility with `ERC721Enumerable` standard
- Records are stored as a mapping from tokenId to ConsumptionRecordEntity.
- Records are indexed by owner to allow efficient lookups by owner.
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
/// @notice Record information for a consumption record
/// @dev Stores basic metadata about who submitted the record, when, who owns it, and includes metadata
struct ConsumptionRecordEntity {
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
    - One-time initializer. Sets CRA Registry and owner, initializes OZ upgradeable base contracts.
    - Requirements: non-zero addresses.

- function submit(uint256 tokenId, address recordOwner, string[] memory keys, bytes32[] memory values)
    - Only callable by an active CRA (onlyActiveCRA).
    - Creates a single record at current block.timestamp.
    - Validations:
        - tokenId should be a valid hash 
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
    - Allows multiple submit(...) calls in a single transaction, each encoded as calldata and delegated internally.
    - Effects:
        - Executes each submit with shared access control and pause checks; each inner call emits its own Submitted
          event.
    - Reverts: EmptyBatch, BatchSizeTooLarge, InvalidCall

- exists(bytes32 crHash) -> bool
    - Returns whether a record exists.

- getTokenData(uint256 tokenId) -> ConsumptionRecordEntity
    - Returns the full record structure.

- balanceOf(address owner) -> uint256
    - Returns a number of tokens owned by the given address.
- 
- tokenOfOwnerByIndex(address owner, uint256 index) -> uint256
    - Returns the tokenId at the given index for the owner.

- totalSupply() -> uint256
    - Returns total number of stored tokens (monotonic increment on submission).

- owner() -> address
    - Returns contract owner.

- supportsInterface(bytes4 interfaceId) -> bool
    - ERC165Compatible; currently delegates to super and can be extended.

# Events and Errors

Events (from IConsumptionRecord):

- Minted(address indexed minter, address indexed to, uint256 indexed tokenId)

Errors (from IConsumptionRecord):

- AlreadyExists()
- InvalidTokenId()
- InvalidMetadata(string reason)

# Record Identity and Hashing

- tokenId is a 32-byte identifier supplied by the caller (CRA). The contract treats it as an opaque identifier.

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

# Validation Rules Summary

On submit:

- tokenId validated to have a non-zero hash (InvalidTokenId)
- owner != address(0) (InvalidOwner)
- Record must not pre-exist (AlreadyExists)
- keys.length == values.length (InvalidMetadata)
- All keys are non-empty strings (InvalidMetadata)

# Integration Notes

- CRA Registry: The contract relies on CRA Registry to authorize CRAs. Deployments must ensure CRA registry is set and
  CRAs are onboarded/activated appropriately.
- Tooling: The project ships Foundry scripts for deterministic deployments and upgrades.

# Security Considerations

- OnlyActiveCRA gate prevents unauthorized submissions; ensure CRA Registry correctness and governance.
- Metadata is unvalidated beyond shape; avoid storing sensitive information in plaintext. Use hashing or encryption
  off-chain if needed.
- Upgrade power is centralized to the owner; secure the owner key or use a timelock/multisig.
