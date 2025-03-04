// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Dice.sol";

/*
1. First create dice using the Dice contract
2. Transfer both die to this contract using the contract's address
3. Use setBattlePair from each player's account to decide enemy
4. Use the battle function to roll, stop rolling and then compare the numbers
5. The player with the higher number gets BOTH dice
6. If there is a tie, return the dice to their previous owner
*/

contract DiceBattle {
    Dice diceContract;
    mapping(address => address) battle_pair;

    constructor(Dice diceAddress) {
        diceContract = diceAddress;
    }

    function setBattlePair(uint256 id, address enemy) public {
        // Require that only prev owner can allow an enemy
        require(msg.sender == diceContract.getPrevOwner(id), "Only the owner can allow an enemy");
        // Each player can only select one enemy
        require(battle_pair[msg.sender] == address(0), "You can only select one enemy");
        battle_pair[msg.sender] = enemy;
    }

    function battle(uint256 myDice, uint256 enemyDice) public {
        // Require that battle_pairs align, ie each player has accepted a battle with the other
        address myAddress = diceContract.getPrevOwner(myDice);
        address enemyAddress = diceContract.getPrevOwner(enemyDice);
        require(enemyAddress == battle_pair[myAddress] && myAddress == battle_pair[enemyAddress], "Each player must accept a battle with the other");
        // Run battle
        diceContract.roll(myDice);
        diceContract.roll(enemyDice);
        diceContract.stopRoll(myDice);
        diceContract.stopRoll(enemyDice);

        if (diceContract.getDiceNumber(myDice) > diceContract.getDiceNumber(enemyDice)) {
            diceContract.transfer(myDice, myAddress);
            diceContract.transfer(enemyDice, myAddress);
        } else if (diceContract.getDiceNumber(myDice) < diceContract.getDiceNumber(enemyDice)) {
            diceContract.transfer(myDice,enemyAddress);
            diceContract.transfer(enemyDice, enemyAddress);
        } else {
            diceContract.transfer(myDice, myAddress);
            diceContract.transfer(enemyDice, enemyAddress);
        }
    }

    //Add relevant getters and setters
    function getBattlePair(address player) public view returns (address) {
        return battle_pair[player];
    }
}
