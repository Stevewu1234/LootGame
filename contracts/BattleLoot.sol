//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILootProject.sol";

contract BattleLoot is Ownable {
    
    mLootProject public mloot;

    IERC20 public rewardToken;

    uint256 public rewardAmountPerRound;

    uint256 public constant MAXROUND = 10;

    uint256 public totalWarriors;

    struct BattleByRanking {
        address acceptorAddress;
        uint256 happenedTime;
        bool result;
        uint256 fightNumber;
    }

    struct BattleByRarityIndex {
        address acceptorAddress;
        uint256 challengerPower;
        uint256 acceptorPower;
        uint256 happenedTime;
        bool result;
    }

    struct Warriors {
        address warriorAddress;
        uint256 originalTokenId;
        uint256 rarityRanking;
        uint256 rarityIndex;
    }

    mapping ( address => BattleByRanking ) public battleDetailsByRanking;

    mapping ( address => BattleByRarityIndex ) public battleDetailsByRarityIndex;

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

    function pvpBattleByRanking() external {
        address challengerAddress = _msgSender();
        require(currentIndex[challengerAddress] != 0, "pvpBattle: please register your role at first");
        
        // get warriors message
        uint256 warriorIndex = currentIndex[challengerAddress];
        Warriors memory challenger = candidateWarriors[warriorIndex];

        // select a random candidate warriors by challenger's basic power.
        uint256 rand = uint256(keccak256(abi.encodePacked(toString(challenger.rartiyRanking), toString(block.timestamp))));
        uint256 randomWarriorNumber = rand % totalWarriors;
        Warriors memory acceptor = candidateWarriors[randomWarriorNumber];

        // pvp battle
        uint256 warriorRanking = challenger.rartiyRanking;
        uint256 acceptorRanking = acceptor.rartiyRanking;

        battleDetailsByRanking[challengerAddress].acceptorAddress = acceptor.warriorAddress;
        battleDetailsByRanking[challengerAddress].happenedTime = block.timestamp;

        if(warriorRanking < acceptorRanking) {
            battleDetailsByRanking[challengerAddress].result = true;
            
            rewardToken.transfer(challengerAddress, rewardAmountPerRound);
        } else {
            
            battleDetailsByRanking[challengerAddress].result = false;
            battleDetailsByRanking[challengerAddress].fightNumber++;

            if(battleDetailsByRanking[challengerAddress].fightNumber == 5) {
                rewardToken.transfer(challengerAddress, rewardAmountPerRound);
                battleDetailsByRanking[challengerAddress].fightNumber = 0;
            }
        }
        
        emit pvpBattledByRanking(warriorIndex, challengerAddress, acceptor.warriorAddress, battleDetailsByRanking[challengerAddress].result);
    }


    function pvpBattleByRarityIndex() external {
        address challengerAddress = _msgSender();
        require(currentIndex[challengerAddress] != 0, "pvpBattle: please register your role at first");


        // get warriors message
        uint256 warriorIndex = currentIndex[challengerAddress];
        Warriors memory challenger = candidateWarriors[warriorIndex];

        // select a random candidate warriors by challenger's basic power.
        uint256 rand = uint256(keccak256(abi.encodePacked(toString(challenger.rartiyRanking), toString(challenger.rarityIndex), toString(block.timestamp))));
        uint256 randomWarriorNumber = rand % totalWarriors;
        Warriors memory acceptor = candidateWarriors[randomWarriorNumber];

        // pvp battle
        uint256 warriorPower = _calculateRandomScore(challenger.originalTokenId, challenger.rarityIndex);
        uint256 acceptorPower = _calculateRandomScore(acceptor.originalTokenId, acceptor.rarityIndex);

        battleDetailsByRarityIndex[challengerAddress].acceptorAddress = acceptor.warriorAddress;
        battleDetailsByRarityIndex[challengerAddress].happenedTime = block.timestamp;

        if(warriorPower > acceptorPower) {
            battleDetailsByRarityIndex[challengerAddress].result = true;
            
            rewardToken.transfer(challengerAddress, rewardAmountPerRound);
        } else {
            
            battleDetailsByRarityIndex[challengerAddress].result = false;
            battleDetailsByRarityIndex[challengerAddress].fightNumber++;

            if(battleDetailsByRarityIndex[challengerAddress].fightNumber == 5) {
                rewardToken.transfer(challengerAddress, rewardAmountPerRound);
                battleDetailsByRarityIndex[challengerAddress].fightNumber = 0;
            }
        }
        
        emit pvpBattledByRarityIndex(warriorIndex, challengerAddress, acceptor.warriorAddress, battleDetailsByRarityIndex[challengerAddress].result);

    }


    function registerRole(
        uint256 tokenId, 
        uint256 _rartiyRanking, 
        uint256 _rarityIndex
        ) external {

        // transfer your fight token
        require(mloot.ownerOf(tokenId) == _msgSender(), "createRole: you do not own the nft");
        mloot.transferFrom(_msgSender(), address(this), tokenId);

        uint256 nextWarrors = totalWarriors + 1;

        candidateWarriors[nextWarrors].originalTokenId = tokenId;
        candidateWarriors[nextWarrors].rartiyRanking = _rartiyRanking;
        candidateWarriors[nextWarrors].warriorAddress = _msgSender();
        candidateWarriors[nextWarrors].rarityIndex = _rarityIndex * 10000;

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
        mloot.transferFrom(address(0), _msgSender(), tokenId);

        emit roleQuit(tokenId, _msgSender());
    }


    /** ========== exteranl mutative onlyOwner functions ========== */

    function updateRewardToken(address newRewardToken) external onlyOwner {
        rewardToken = IERC20(newRewardToken);

        emit rewardTokenUpdated(newRewardToken);
    }

    function refundRewardToken(address receiver) external onlyOwner {
        uint256 totalAmount = rewardToken.balanceOf(address(this));
        rewardToken.transfer(receiver, totalAmount);

        emit rewardTokenRefund(receiver, totalAmount);
    }

    /** ========== internal view functions ========== */

    // calculate random score basing on user's rarityscore of the nft
    function _calculateRandomScore(uint256 _rarityScore, uint256 tokenId) internal view returns (uint256 randomScore) {
        uint256 rand = uint256(keccak256(abi.encodePacked(toString(tokenId), toString(_rarityScore), toString(block.timestamp))));
        (uint256 minScore, uint256 maxScore) = _getScoreRange(_rarityScore);
        uint256 levelRange = maxScore - minScore;
        
        return randomScore = (rand % levelRange) + minScore;
    }

    function _getScoreRange(uint256 _rarityScore) internal pure returns (uint256 minScore, uint256 maxScore) {
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

    function _calculateRange(uint256 _rarityScore, uint256 ratio) internal pure returns (uint256, uint256) {
        uint256 minScore = _rarityScore - _rarityScore * ratio / 100;
        uint256 maxScore = _rarityScore + _rarityScore * ratio / 100;
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

    event pvpBattledByRanking(uint256 indexed warriorIndex, address indexed warriorAddress, address acceptorAddress, bool result);

    event pvpBattledByRarityIndex(uint256 indexed warriorIndex, address indexed warriorAddress, address acceptorAddress, bool result);

    event roleQuit(uint256 indexed tokenId, address playerAddress);

    event rewardTokenUpdated(address indexed newRewardToken);

    event rewardTokenRefund(address indexed receiver, uint256 totalAmount);
}