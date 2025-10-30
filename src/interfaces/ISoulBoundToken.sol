pragma solidity ^0.8.27;

import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/**
 * @notice Base interface for SoulBound NFT tokens which fully supports IERC721Enumerable and
 * partially supports IERC721 (without transfer) methods.
 */
interface ISoulBoundToken is IERC165Upgradeable {
    event Minted(address indexed minter, address indexed to, uint256 indexed tokenId);

    /// @notice Thrown when trying to submit a token that already exists
    error AlreadyExists();
    /// @notice Thrown when trying to submit a token id that is not a hash
    error InvalidTokenId();

    function exists(uint256 tokenId) external view returns (bool);

    // Inherited from IERC721

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    // Inherited from IERC721Enumerable

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}
