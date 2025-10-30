# [0002] Consumption Unit

# Status

Draft

# Version

0001 — Draft, Initial specification

# Context

A Consumption Unit (CU) is an immutable, content-addressed entry representing the aggregated value of a user's Acts of
Consumption for a Worldwide Day and Bank Account, per the Reflection of Acts of Consumption. Each CU
is identified off-chain by a Blake3-based preimage and is submitted on-chain by its 32-byte hash (cuHash). CUs carry
settlement information, worldwide day, and link to the underlying Consumption Record (CR) hashes (and, when applicable,
Consumption Record Amendment hashes) providing provenance and breakdown.

Operational context from the reflection:

- CRA ingests eligible transactions twice per Worldwide Day and creates CRs, then aggregates them into CUs per Account
  and Worldwide Day.
- Deduplication is enforced network-wide by checking that the same CR hash cannot be used in more than one CU.
- Refunds are modeled as negative CRs and can be reflected in subsequent CUs.

Creation is permissioned to active Consumption Reflection Agents (CRAs) via the CRA Registry.

This document describes the on-chain logic and data requirements for the L2 Consumption Unit registry implemented by the
upgradeable smart contract `ConsumptionUnitUpgradeable`.

## Goals

- Deterministic, append-only registry of consumption units keyed by cuHash
- Enforce CRA-level access control for submission
- Capture settlement amounts and worldwide day in a compact form
- Reference one or more `ConsumptionRecord` hashes with global uniqueness per CR hash
- Support efficient batch submissions with single-timestamp semantics
- Remain upgradeable via UUPS with strict owner gating

# Decision

We implement smart contract using Solidity and the UUPS upgradeable proxy pattern. Active CRAs submit CUs that
are stored by content hash, associated to an owner, and carry settlement context. A CU references zero or more CR
hashes, each enforced to be globally unique across all CU submissions to prevent double-linking.

Key design choices:

- Compatibility with `ERC721Enumerable` standard
- Units are stored as a mapping from tokenId to ConsumptionUnitEntity.
- Units are indexed by owner to allow efficient lookups by owner.
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
- MulticallUpgradeable (batched submissions)

# Core Data Structures

Contract: src/consumption_unit/ConsumptionUnitUpgradeable.sol
Interface: src/interfaces/IConsumptionUnit.sol

ConsumptionUnitEntity:

```solidity
struct ConsumptionUnitEntity {
    /// @notice Owner of the consumption unit
    address owner;
    /// @notice Address of the CRA agent who submitted this consumption unit
    address submittedBy;
    /// @notice Timestamp when the consumption unit was submitted
    uint256 submittedAt;
    /// @notice Worldwide day in a compact format YYYYMMDD (e.g., 20250923)
    uint32 worldwideDay;
    /// @notice Amount expressed in natural units (base currency units).
    uint64 settlementAmountBase;
    /// @notice Amount expressed in fractional units (atto, 1e-18). Must satisfy 0 <= amount < 1e18.
    uint128 settlementAmountAtto;
    /// @notice Numeric currency code using ISO 4217
    uint16 settlementCurrency;
    /// @notice Hashes identifying linked consumption records (unique per record)
    uint256[] crIds;
    /// @notice Hashes identifying linked consumption records amendments (unique per record)
    uint256[] amendmentCrIds;
}
```

# API

All functions are available on the proxy.

- initialize(address _craRegistry, address _owner, address _consumptionRecord, address _consumptionRecordAmendment)
    - One-time initializer. Sets CRA Registry and owner; initializes OZ components.
    - Requirements: non-zero addresses.

- submit(
  uint256 tokenId,
  address tokenOwner,
  uint16 settlementCurrency,
  uint32 worldwideDay,
  uint64 settlementAmountBase,
  uint128 settlementAmountAtto,
  uint256[] memory crIds,
  uint256[] memory amendmentIds,
  uint256 timestamp
  ) external onlyActiveCRA
    - Creates a single CU at current block.timestamp.
    - Validations (see Validation Rules): tokenId non-zero and unique, owner non-zero, currency non-zero, amounts shape
      valid; CR hashes and Amendment hashes must be unique globally and must not overlap within the same submission.
    - Effects: persists entity, indexes by owner, increments total counter. 
    - Emits: Minted(cra, tokenOwner, tokenId)

- multicall(bytes[] data) -> bytes[] results
    - Allows multiple submit(...) calls in a single transaction, each encoded as calldata and delegated internally.
    - Effects:
        - Executes each submit with shared access control and pause checks; each inner call emits its own Submitted
          event.

- exists(uint256 tokenId) -> bool
    - Returns whether a CU exists.

- getTokenData(uint256 tokenId) -> ConsumptionUnitEntity
    - Returns the full CU structure.

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

Events (from IConsumptionUnit):

- Minted(address indexed minter, address indexed to, uint256 indexed tokenId)

Errors (from IConsumptionUnit):

- AlreadyExists()
- InvalidTokenId()
- InvalidOwner();
- ConsumptionRecordAlreadyExists();
- InvalidSettlementCurrency();
- InvalidAmount();
- InvalidConsumptionRecords();

# Record Identity and Referencing

- tokenId is a 32-byte hash identifier supplied by the caller (CRA). The contract treats it as an opaque identifier.
- Uniqueness is enforced per CU: the same tokenId cannot be reused.
- Each referenced CR hash (crIds[i]) must be unique globally across all CUs. Likewise, each referenced amendment
  hash (amendmentCrIds[i]) must be unique globally across all CUs. The contract tracks both sets to prevent
  double-linking.
- No overlap is allowed within a single submission between crHashes and amendmentCrHashes.
- The registry does not compute or verify cuHash or the linked hashes on-chain; upstream systems define their hashing
  schemes.

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

# Validation Rules Summary

On submit and per-item in multicall:

- tokenId validated to have a non-zero hash (InvalidTokenId)
- owner != address(0) (InvalidOwner)
- CU must not pre-exist (AlreadyExists)
- settlementCurrency != 0 (InvalidSettlementCurrency)
- Amounts: not both zero AND atto < 1e18 (InvalidAmount)
- Each crId must not have been used before (ConsumptionRecordAlreadyExists)
- Each amendmentCrId must not have been used before
- No overlap between crIds and amendmentCrIds (InvalidConsumptionRecords)

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
- Settlement values are immutable after submission.
