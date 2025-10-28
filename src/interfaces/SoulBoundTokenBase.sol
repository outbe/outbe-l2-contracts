pragma solidity ^0.8.27;

import {Address} from "../../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {ISoulBoundToken} from "./ISoulBoundToken.sol";
import {Strings} from "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

abstract contract SoulBoundTokenBase is ISoulBoundToken {
    using Strings for uint256;
    using Address for address;

    mapping(uint256 tokenId => address) private _owners;

    mapping(address owner => uint256) private _balances;

    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /// @inheritdoc ISoulBoundToken
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /// @inheritdoc ISoulBoundToken
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ISoulBoundToken).interfaceId;
    }

    /// @inheritdoc ISoulBoundToken
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /// @inheritdoc ISoulBoundToken
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /// @inheritdoc ISoulBoundToken
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }
}
