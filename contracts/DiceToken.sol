// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract DiceToken {
    ERC20 public erc20Contract;
    uint256 public supplyLimit;
    uint256 public currentSupply;
    address public owner;
    
    constructor() {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
        supplyLimit = 10000;
    }

    event creditChecked(uint256 credit);

    function getCredit() public payable {
        uint256 amt = msg.value / 10000000000000000; // Get DTs eligible
        require(erc20Contract.totalSupply() + amt < supplyLimit, "DT supply is not enough");
        // erc20Contract.transferFrom(owner, msg.sender, amt);
        erc20Contract.mint(msg.sender, amt);
        
    }

    function checkCredit() public returns(uint256) {
        uint256 credit = erc20Contract.balanceOf(msg.sender);
        emit creditChecked(credit);
        return credit;
    }

    function transferCredit(address receipt, uint256 amt) public {
        erc20Contract.transfer(receipt, amt);
    }

    function transferCreditFrom(address from, address to, uint256 amt) public {
        erc20Contract.transferFrom(from, to, amt);
    }

    function giveAllowance(address receipt, uint256 amt) public {
        erc20Contract.approve(receipt, amt);
    }

    function checkOtherCredit(address other) public returns(uint256) {
        uint256 credit = erc20Contract.balanceOf(other);
        emit creditChecked(credit);
        return credit;
    }

}