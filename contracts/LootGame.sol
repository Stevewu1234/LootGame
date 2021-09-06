//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


interface LootProject {

    function getWeapon(uint256 tokenId) external view returns (string memory);

    function getChest(uint256 tokenId) external view returns (string memory);

    function getHead(uint256 tokenId) external view returns (string memory);

    function getWaist(uint256 tokenId) external view returns (string memory);

    function getFoot(uint256 tokenId) external view returns (string memory);

    function getHand(uint256 tokenId) external view returns (string memory);

    function getNeck(uint256 tokenId) external view returns (string memory);

    function getRing(uint256 tokenId) external view returns (string memory);
}

contract LootGame {
    
    LootProject public loot;

    struct Battle {
        address challenger,
        address acceptor,
        uint256 challengerPower,
        uint256 acceptorPower,
        uint256 happenedTime
    }

    mapping ( address => Battle ) public BattleDetails;


    mapping (address => mapping (uint256 => bool) ) candidateWarriors;


    constructor (address _lootaddress) {
        loot = LootProject(_lootaddress);
    }



    function battle() public {
        
    }


    function createRole(uint256 tokenId) public {
        require(loot.transferFrom(_msgSender(), address(this), tokenId), "createRole: fail to create loot role");
    }



    /** ========== internal view functions ========== */

    function _calculateRandomScore(uint256 _rarityScore, uint256 tokenId) internal view returns (uint256) {
        return randomScore = _getRandom(tokenId, _rarityScore) % _getScoreRange(_rarityScore);
    }

    function _getRandom(uint256 tokenId, uint256 _rarityScore) internal view returns (uint256) {
        uint256 rand = uint256(abi.encodepacked(toString(tokenId), toString(_rarityScore), toString(block.timestamp)));
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
}