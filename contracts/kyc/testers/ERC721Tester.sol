// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC721} from "../ERC721.sol";

contract ERC721Tester is ERC721 {
    event Minted(uint256 indexed tokenId, address indexed owner);

    function internalMint(address owner) public returns (uint256) {
        uint256 tokenId = _mint(owner);
        emit Minted(tokenId, owner);
        return tokenId;
    }
}
