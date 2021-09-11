//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract cbtest is ERC20Burnable, Ownable {
    
    address public childChainManagerProxy;
    constructor (address _childChainManagerProxy) ERC20("child b test", "cbtest") {
        childChainManagerProxy = _childChainManagerProxy;
    }


    /** ========== external mutative functions ========== */
    function deposit(address account, bytes calldata depositData) external {
        require(childChainManagerProxy == _msgSender(), "deposit: you're not allowed to deposit");

        uint256 amount = abi.decode(depositData, (uint256));

        _mint(account, amount);

        emit tokenDeposited(account, amount);
    }

    function withdraw(uint256 amount) external {
        require(childChainManagerProxy == _msgSender(), "withdraw: you're not allowed to withdraw");
        
        burn(amount);

        emit tokenBurnt(msg.sender, amount);
    }

    /** ========== external mutative onlyOwner functions ========== */

    function updateChildChainManger(address _newchildChainMangerAddress) external onlyOwner {
        require(_newchildChainMangerAddress != address(0), "updateChildChainManger: you can not set 0 address");
        childChainManagerProxy = _newchildChainMangerAddress;
    }


    /** ========== event ========== */

    event tokenDeposited(address indexed receiver, uint256 depositedAmount);

    event tokenBurnt(address indexed account, uint256 burntAmount);
}