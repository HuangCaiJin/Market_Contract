// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

interface IERC1155 {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
    function exist(uint _id) external view returns (bool);
    function mint(
        address from,
        address to, 
        uint _tokenID,
        uint amount,
        bytes calldata data
    ) external;
}
