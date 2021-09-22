//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract pLoot is ERC721, Ownable {


    address public childChainManagerProxy;

    address public battleAddress;

    constructor (address _childChainManagerAddress, address _battleAddress)  ERC721("polygon mloot", "pmLoot") {
        childChainManagerProxy = _childChainManagerAddress;
        battleAddress = _battleAddress;
    }


    // onlyOwner
    function updateChildChainManger(address _newchildChainMangerAddress) external onlyOwner {
        require(_newchildChainMangerAddress != address(0), "updateChildChainManger: you can not set 0 address");
        childChainManagerProxy = _newchildChainMangerAddress;
    }

    function updateBattleAddress(address _newbattle) external onlyOwner {
        battleAddress = _newbattle;
    }


    // polygon mapping
    function deposit(address account, bytes calldata depositData) external {
        require(childChainManagerProxy == _msgSender(), "deposit: you're not allowed to deposit");

        uint256 tokenId = abi.decode(depositData, (uint256));

        _mint(account, tokenId);
        _approve(battleAddress, tokenId);

        emit Transfer(address(0), account, tokenId);
    }

    function withdraw(uint256 tokenId) external {
        
        _burn(tokenId);

        emit Transfer(msg.sender, address(0), tokenId);
    }
}