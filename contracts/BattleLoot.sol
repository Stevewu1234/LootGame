//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILootProject.sol";
import "hardhat/console.sol";

contract BattleLoot is Ownable {
    
    LootProject public mmloot; // mapping mloot on polygon network

    IERC20 public rewardToken;

    uint256 public rewardAmountPerRound;

    uint256 public constant MAXROUND = 10;

    uint256 public totalWarriors;

    struct BattleByRanking {
        address acceptorAddress;
        uint256 challengerRanking;
        uint256 acceptorRanking;
        uint256 failNumber;
        bool result;
    }

    struct BattleByRarityIndex {
        address acceptorAddress;
        uint256 challengerPower;
        uint256 acceptorPower;
        uint256 failNumber;
        bool result;
    }

    struct Warriors {
        address warriorAddress;
        uint256[] originalTokenIds;
        uint256[] rarityRankings;
        uint256[] rarityIndexes;
    }

    mapping ( address => BattleByRanking ) public battleDetailsByRanking;

    mapping ( address => BattleByRarityIndex ) public battleDetailsByRarityIndex;

    // record candidate warriors.
    mapping ( uint256 => Warriors ) private candidateWarriors;

    // the number among warriors.
    mapping ( address => uint256 ) private warriorsIndex;

    // record account's claimable reward.
    mapping ( address => uint256 ) private claimableReward;

    constructor (
        address _mmlootaddress, 
        address rewardTokenAddress,
        uint256 _rewardAmountPerRound
        ) {
        mmloot = LootProject(_mmlootaddress);
        rewardToken = IERC20(rewardTokenAddress);
        rewardAmountPerRound = _rewardAmountPerRound;
    }

    /** ========== public view functions ========== */

    function getYourStakedToken() public view returns (string memory _stakedTokenId) {
        uint256[] memory tokenIds = candidateWarriors[warriorsIndex[_msgSender()]].originalTokenIds;
        for(uint256 i = 0; i < tokenIds.length; i++ ) {
            if(tokenIds[i] != 0) {
                _stakedTokenId = string(abi.encodePacked(_stakedTokenId, tokenIds[i]));
            }
        }
    }

    function getYourStakedToken(address account) public view returns (string memory _stakedTokenId) {
        uint256[] memory tokenIds = candidateWarriors[warriorsIndex[account]].originalTokenIds;
        for(uint256 i = 0; i < tokenIds.length; i++ ) {
            if(tokenIds[i] != 0) {
                _stakedTokenId = string(abi.encodePacked(_stakedTokenId, tokenIds[i]));
            }
        }
    }

    function getClaimableReward(address account) public view returns (uint256 rewardAmount) {
        return claimableReward[account];
    }

    function getCandidateWarriors(address warriorAddress) public view returns (
        uint256 warriorId,
        address _warriorAddress,
        uint256[] memory _originalTokenIds,
        uint256[] memory _rarityRankings,
        uint256[] memory _rarityIndexes
    ) {
        Warriors memory warrior = candidateWarriors[warriorsIndex[warriorAddress]];
        warriorId = warriorsIndex[warriorAddress];
        _warriorAddress = warrior.warriorAddress;
        _originalTokenIds = warrior.originalTokenIds;
        _rarityRankings = warrior.rarityRankings;
        _rarityIndexes = warrior.rarityIndexes;
    }


    /** ========== external mutative functions ========== */

    function pvpBattleByRanking(uint256 tokenId) external returns (bool result) {
        address challengerAddress = _msgSender();
        require(warriorsIndex[challengerAddress] != 0, "pvpBattleByRanking: please register your role at first");
        require(_checkTokenExisted(challengerAddress, tokenId), "pvpBattleByRanking: please register tokenId first");
        
        // get challenger message 
        ( , , uint256[] memory tokenIds, uint256[] memory rankings, ) = getCandidateWarriors(challengerAddress);
        uint256 challengerRanking = _getRarityMessage(tokenId, tokenIds, rankings);
        console.log("finish get challenger message");

        // select a random candidate warriors by challenger's basic message.
        (address acceptorAddress, , uint256 acceptorRanking, ) = _getRandomAcceptor(tokenId);
        console.log("finish get select random user");
        
        // pvp battle
        return result = _battleByRanking(challengerAddress, acceptorAddress, challengerRanking, acceptorRanking);
        console.log("finish battle");
        
        emit pvpBattledByRanking(challengerAddress, acceptorAddress, result);
    }


    function pvpBattleByRarityIndex(uint256 tokenId) external returns (bool result) {
        address challengerAddress = _msgSender();
        require(warriorsIndex[challengerAddress] != 0, "pvpBattleByRarityIndex: please register your role at first");
        require(_checkTokenExisted(challengerAddress, tokenId), "pvpBattleByRarityIndex: please register tokenId first");

        // get warriors message
        (, , uint256[] memory tokenIds, , uint256[] memory indexes) = getCandidateWarriors(challengerAddress);
        uint256 challengerRarityIndex = _getRarityMessage(tokenId, tokenIds, indexes);

        // select a random candidate acceptor address by challenger's basic power.
        (address acceptorAddress, uint256 randomAcceptorTokenId, , uint256 acceptorRarityIndex) = _getRandomAcceptor(tokenId);

        // pvp battle
        uint256 challengerPower = _calculateRandomScore(challengerRarityIndex, tokenId);
        uint256 acceptorPower = _calculateRandomScore(acceptorRarityIndex, randomAcceptorTokenId);
        return result = _battleByIndex(challengerAddress, acceptorAddress, challengerPower, acceptorPower);

        emit pvpBattledByRarityIndex(challengerAddress, acceptorAddress, result);
    }


    function registerRole(
        uint256 tokenId, 
        uint256 _rartiyRanking, 
        uint256 _rarityIndex
        ) external {

        // transfer your fight token
        require(mmloot.ownerOf(tokenId) == _msgSender(), "createRole: you do not own the nft");
        mmloot.transferFrom(_msgSender(), address(this), tokenId);

        uint256 warriorId;

        if(warriorsIndex[_msgSender()] == 0) {
            warriorId = totalWarriors + 1;
            totalWarriors++;
            warriorsIndex[_msgSender()] = warriorId;
        } else { warriorId = warriorsIndex[_msgSender()]; }
        
        candidateWarriors[warriorId].originalTokenIds.push(tokenId);
        candidateWarriors[warriorId].rarityRankings.push(_rartiyRanking);
        candidateWarriors[warriorId].warriorAddress = _msgSender();
        candidateWarriors[warriorId].rarityIndexes.push(_rarityIndex);

        emit roleRegistered(_msgSender(), tokenId, _rartiyRanking, _rarityIndex);
    }

    function quitFromGame(uint256 tokenId) external {        

        // delete player tokenId
        require(_checkTokenExisted(_msgSender(), tokenId), "quitFromGame: Sorry, you are not a candidate warrior.");
        require(_deleteTokenIdRecords(tokenId), "quitFromGame: fail to delete tokenId records");

        // check player records and delete player records if no tokenId exists.
        if(candidateWarriors[warriorsIndex[_msgSender()]].originalTokenIds.length == 0) {
            delete warriorsIndex[_msgSender()];
            totalWarriors--;
        }

        // return player's token
        mmloot.transferFrom(address(this), _msgSender(), tokenId);

        emit roleQuit(tokenId, _msgSender());
    }


    // users claim their reward

    function claim() external {
        require(claimableReward[_msgSender()] >= rewardToken.balanceOf(address(this)), "claim: no enough token to claim");

        rewardToken.transfer(_msgSender(), claimableReward[_msgSender()]);

        emit rewardTokenClaimed(_msgSender(), claimableReward[_msgSender()]);
    }


    /** ========== exteranl mutative onlyOwner functions ========== */

    function updateRewardToken(address newRewardToken) external onlyOwner {
        rewardToken = IERC20(newRewardToken);

        emit rewardTokenUpdated(newRewardToken);
    }

    function removeRewardToken(address receiver) external onlyOwner {
        uint256 totalAmount = rewardToken.balanceOf(address(this));
        rewardToken.transfer(receiver, totalAmount);

        emit rewardTokenRefund(receiver, totalAmount);
    }

    function updateMMLoot(address newMMLoot) external onlyOwner {
        mmloot = LootProject(newMMLoot);
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
        
        if(_rarityScore > 1500000 && _rarityScore <= 2000000) {
            return _calculateRange(_rarityScore, 5);
        } else if(_rarityScore > 2000000 && _rarityScore <= 2500000) {
            return _calculateRange(_rarityScore, 10);
        } else if(_rarityScore > 2500000 && _rarityScore <= 3000000) {
            return _calculateRange(_rarityScore, 15);
        } else if(_rarityScore > 3000000 && _rarityScore <= 3500000) {
            return _calculateRange(_rarityScore, 20);
        } else if(_rarityScore > 3500000 && _rarityScore <= 4100000) {
            return _calculateRange(_rarityScore, 25);
        }
    }

    function _calculateRange(uint256 _rarityScore, uint256 ratio) internal pure returns (uint256, uint256) {
        uint256 minScore = _rarityScore - _rarityScore * ratio / 100;
        uint256 maxScore = _rarityScore + _rarityScore * ratio / 100;
        return (minScore, maxScore);
    }





    function _checkTokenExisted(address account, uint256 tokenId) internal view returns (bool existed) {
        uint256[] memory tokenIds = candidateWarriors[warriorsIndex[account]].originalTokenIds;
        for(uint256 i = 0; i < tokenIds.length; i++ ){
            if(tokenId == tokenIds[i]) {
                existed = true;
            }
        }
    }

    function _getRarityMessage(uint256 tokenId, uint256[] memory _tokenIds, uint256[] memory _array) internal pure returns (uint256 targetData) {
        require(_tokenIds.length == _array.length, "not match");

        for(uint256 i = 0; i < _tokenIds.length; i++ ) {
            if(tokenId == _tokenIds[i]) {
                return targetData = _array[i];
            }
        }
    }

    function _getRandomAcceptor(uint256 challengerTokenId) internal pure returns (
        address acceptorAddress, 
        uint256 randomAcceptorTokenId,
        uint256 acceptorRanking,
        uint256 acceptorRarityIndex
    ) {
        // select a random candidate acceptor address by challenger's basic power.
        uint256 rand = uint256(keccak256(abi.encodePacked(toString(challengerTokenId), toString(block.timestamp))));
        uint256 randomWarriorNumber = rand % totalWarriors;
        acceptorAddress = candidateWarriors[randomWarriorNumber].warriorAddress;
        (, , uint256[] memory atokenIds, uint256[] memory aRankings, uint256[] memory aIndexes) = getCandidateWarriors(acceptorAddress);

        // deleted tokenId will still occupy array position, generate new nonzero tokenId array to storage available tokenIds.
        uint256[] memory newArray;
        for(uint256 i = 0; i < atokenIds.length; i++ ){
            if (atokenIds[i] != 0) {
                newArray.push(atokenIds[i]);
            }
        }



        // select random tokenId from accpetor.
        randomAcceptorTokenId = newArray[(rand % newArray.length) - 1];
        acceptorRanking = _getRarityMessage(randomAcceptorTokenId, atokenIds, aRankings);
        acceptorRarityIndex = _getRarityMessage(randomAcceptorTokenId, atokenIds, aIndexes);
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

    /** ========== internal mutative functions ========== */

    function _deleteTokenIdRecords(uint256 tokenId) internal returns (bool deleted) {
        Warriors storage warriro = candidateWarriors[warriorsIndex[_msgSender()]];
        uint256[] memory tokenIds = warriro.originalTokenIds;

        for(uint256 i = 0; i < tokenIds.length; i++ ) {
            if(tokenId == tokenIds[i]) {
                delete warriro.originalTokenIds[i];
                delete warriro.rarityRankings[i];
                delete warriro.rarityIndexes[i];

                deleted = true;
            }
        }
    }

    function _recordRewardAmount(address account) private {
        claimableReward[account] =  claimableReward[account] + rewardAmountPerRound;

        emit recordedReward(account, claimableReward[account]);
    }


    function _battleByRanking(
        address _challengerAddress,
        address _acceptorAddress, 
        uint256 _challengerRanking, 
        uint256 _acceptorRanking
    ) internal returns (bool result) {
        battleDetailsByRanking[_challengerAddress].acceptorAddress = _acceptorAddress;
        battleDetailsByRanking[_challengerAddress].challengerRanking = _challengerRanking;
        battleDetailsByRanking[_challengerAddress].acceptorRanking = _acceptorRanking;

        if(_challengerRanking < _acceptorRanking) {

            battleDetailsByRanking[_challengerAddress].result = true;
            _recordRewardAmount(_challengerAddress);

            return result = true;

        } else {
            
            battleDetailsByRanking[_challengerAddress].result = false;
            battleDetailsByRanking[_challengerAddress].failNumber++;

            if(battleDetailsByRanking[_challengerAddress].failNumber == 5) {
                _recordRewardAmount(_challengerAddress);
                battleDetailsByRanking[_challengerAddress].failNumber = 0;
            }

            return result = false;
        }
    }

    function _battleByIndex(
        address _challengerAddress,
        address _acceptorAddress,
        uint256 _challengerIndex,
        uint256 _acceptorIndex
    ) internal returns (bool result) {
        battleDetailsByRarityIndex[_challengerAddress].acceptorAddress = _acceptorAddress;
        battleDetailsByRarityIndex[_challengerAddress].challengerPower = _challengerIndex;
        battleDetailsByRarityIndex[_challengerAddress].acceptorPower = _acceptorIndex;

        if(_challengerIndex > _acceptorIndex) {
            battleDetailsByRarityIndex[_challengerAddress].result = true;
            
            _recordRewardAmount(_challengerAddress);

            return result = true;
        } else {
            
            battleDetailsByRarityIndex[_challengerAddress].result = false;
            battleDetailsByRarityIndex[_challengerAddress].failNumber++;

            if(battleDetailsByRarityIndex[_challengerAddress].failNumber == 5) {
                _recordRewardAmount(_challengerAddress);
                battleDetailsByRarityIndex[_challengerAddress].failNumber = 0;
            }

            return result = false;
        }
    }


    /** ========== event ========== */

    event roleRegistered(address indexed role, uint256 indexed tokenId, uint256 rarityRanking, uint256 rarityIndex);

    event pvpBattledByRanking(address indexed warriorAddress, address acceptorAddress, bool result);

    event pvpBattledByRarityIndex(address indexed warriorAddress, address acceptorAddress, bool result);

    event roleQuit(uint256 indexed tokenId, address playerAddress);

    event rewardTokenUpdated(address indexed newRewardToken);

    event rewardTokenRefund(address indexed receiver, uint256 totalAmount);

    event recordedReward(address indexed receiver, uint256 totalAmount);

    event rewardTokenClaimed(address indexed receiver, uint256 claimedToken);
}