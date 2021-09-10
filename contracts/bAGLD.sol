//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Btest is ERC20, Ownable {
    

    constructor () ERC20("Btest", "BT") {
        _mint(_msgSender(), 1000000000e18);
    }

    function mintmore(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

}