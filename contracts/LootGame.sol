//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ILootProject.sol";

contract LootGame {
    
    LootProject public loot;

    IERC20 public rewardToken;

    uint256 public rewardAmountPerRound;

    uint256 public constant MAXROUND = 10;

    uint256 public totalWarriors;

    struct Battle {
        address acceptor,
        uint256 challengerPower,
        uint256 acceptorPower,
        uint256 happenedTime,
        bool result;
    }

    struct Warriors {
        address warriorAddress,
        address originalNFT,
        uint256 originalTokenId,
        uint256 initialPower
    }

    mapping ( address => Battle ) public battleDetails;

    // record candidate warriors
    mapping ( uint256 => Warriors ) public candidateWarriors;

    mapping ( address => uint256 ) public currentIndex;

    constructor (
        address _lootaddress, 
        address rewardTokenAddress
        ) {
        loot = LootProject(_lootaddress);
        rewardToken = IERC20(rewardTokenAddress);
    }

    /** ========== external mutative functions ========== */

    function pvpBattle() external {
        address warriorAddress = _msgSender();
        require(currentIndex[warriorAddress] != 0, "pvpBattle: please register your role at first");
        
        // get warriors message
        uint256 warriorIndex = currentIndex[warriorAddress];
        Warriors memory warrior = candidateWarriors[warriorIndex];

        // select a random candidate warriors by challenger's basic power.
        uint256 rand = uint256(abi.encodePacked(toString(warrior.initialPower)));
        uint256 randomWarriorNumber = rand % totalWarriors;
        Warriors memory acceptor = candidateWarriors[randomWarriorNumber];

        // pvp battle
        uint256 warriorPower = _calculateRandomScore(warrior.originalTokenId, warrior.initialPower);
        uint256 acceptorPower = _calculateRandomScore(acceptor.originalTokenId, acceptor.initialPower);

        battleDetails[warriorAddress].acceptor = acceptor;
        battleDetails[warriorAddress].challengerPower = warriorPower;
        battleDetails[warriorAddress].acceptorPower = acceptorPower;
        battleDetails[warriorAddress].happenedTime = block.timestamp;

        if(warriorPower > acceptorPower) {
            battleDetails[warriorAddress].result = true;
            
            rewardToken.transfer(warriorAddress, rewardAmountPerRound);
        } else {
            battleDetails[warriorAddress].result = false;
        }
        
        emit pvpBattled(warriorIndex, warriorAddress, acceptor.acceptorAddress, battleDetails[warriorAddress].result);
    }


    function registerRole(uint256 tokenId, uint256 rarityscore) external {

        // transfer your fight token
        require(loot.transferFrom(_msgSender(), address(this), tokenId), "createRole: fail to create loot role");

        uint256 nextWarrors = totalWarriors + 1;

        candidateWarriors[nextWarrors].originalNFT = address(loot);
        candidateWarriors[nextWarrors].originalTokenId = tokenid;
        candidateWarriors[nextWarrors].initialPower = rarityscore;
        candidateWarriors[nextWarrors].warriorAddress = _msgSender();
        currentIndex[_msgSender()] = nextWarrors;

        totalWarriors++;

        emit roleRegistered(_msgSender(), tokenId, rarityscore);
    }

    function quitFromGame(uint256 tokenId) external {

        require(currentIndex[_msgSender()] == tokenId, "quitFromGame: Sorry, you do not a candidate warrior.");

        // delete player records
        delete currentIndex[_msgSender()];
        delete candidateWarriors[tokenId];
        totalWarriors--; 

        // return player's token
        loot.transfer(_msgSender(), tokenId);

        emit roleQuit(tokenId, _msgSender());
    }


    /** ========== internal view functions ========== */

    // calculate random score basing on user's rarityscore of the nft
    function _calculateRandomScore(uint256 _rarityScore, uint256 tokenId) internal view returns (uint256) {
        uint256 rand = uint256(abi.encodepacked(toString(tokenId), toString(_rarityScore), toString(block.timestamp)));
        (uint256 minScore, uint256 maxScore) = _getScoreRange(_rarityScore);
        uint256 levelRange = maxScore - minScore;
        
        return randomScore = (rand % levelRange) + minScore;
    }

    function _getScoreRange(uint256 _rarityScore) internal view returns (uint256 minScore, uint256 maxScore) {
        require(_rarityScore != 0, "rarity score of loot must not be null");
        
        if(_rarityScore > 0 && _rarityScore <= 1000) {
            return _calculateRange(_rarityScore, 5);
        } else if(_rarityScore > 1000 && _rarityScore <= 2000) {
            return _calculateRange(_rarityScore, 10);
        } else if(_rarityScore > 2000 && _rarityScore <= 3000) {
            return _calculateRange(_rarityScore, 15);
        } else if(_rarityScore > 3000 && _rarityScore <= 4000) {
            return _calculateRange(_rarityScore, 20);
        } else if(_rarityScore > 4000 && _rarityScore <= 5481) {
            return _calculateRange(_rarityScore, 25);
        }
    }

    function _calculateRange(uint256 _rarityScore, uint256 ratio) internal view returns (uint256, uint256) {
        minScore = _rarityScore - _rarityScore * ratio / 100;
        maxScore = _rarityScore + _rarityScore * ratio / 100;
        return (minScore, maxScore);
    }


    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }


    /** ========== event ========== */

    event roleRegistered(address indexed role, uint256 indexed tokenId, uint256 power);

    event pvpBattled(uint256 indexed warriorIndex, address indexed warriorAddress, address acceptorAddress, bool result);

    event roleQuit(uint256 indexed tokenId, address playerAddress);
}