// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function exist(uint _id) external view returns (bool);
    function mint(
        address from,
        address to, 
        uint _tokenID,
        bytes calldata data
    ) external;
}
