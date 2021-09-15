// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract simpleNFT is ERC721 {

    constructor () ERC721("TEST1","TT") {}

    function claim(uint256 tokenId) public {
        _mint(msg.sender, tokenId);
    }
}