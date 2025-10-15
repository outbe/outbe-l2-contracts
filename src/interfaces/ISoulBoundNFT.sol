pragma solidity ^0.8.27;

interface ISoulBoundNFT {
    // TODO define this interface and add compatibility for all L2 contracts with this
    // The idea of this interface is to be partially compatible with NFT's standard for easy implementation on clients.
    // List of standards to use:
    // - as ref https://docs.openzeppelin.com/contracts/4.x/api/token/ERC721#ierc721enumerable-2

    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///  them has an assigned and queryable owner not equal to the zero address
    /// @dev Note: the ERC-165 identifier for this interface is 0x780e9d63, see
    ///  https://portal.thirdweb.com/tokens/build/extensions/erc-721/ERC721Supply
    function totalSupply() external view returns (uint256);
}
