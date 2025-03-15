// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

//MAY NOT BE NEEDED. BECAUSE ERC20 USUALLY USED TO SUPPORT TOKENS WITH REAL MONETARY VALUE. 
//USED TO SUPPORT TRANSFER OWNERSHIP OF TOKENS ECT. SINCE WE ARENT SUPPORTING THAT, WE CAN JUST SUPPORT THE CREDIFYTOKENS JUST AS
//A MAPPING IN THE CREDIFY PLATFORM.
contract CredifyToken {
    ERC20 public erc20Contract;
    uint256 public supplyLimit;
    uint256 public currentSupply;
    address public owner;
    
    constructor() {
        ERC20 e = new ERC20();
        erc20Contract = e;
        owner = msg.sender;
    }

    event creditChecked(uint256 credit);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not permitted to perform this action!");
        _;
    }

    //Should be called manually by owner in order to transfer ownership to the credify platform to allow rewarding system
    function transferOwnership(address newAddress) onlyOwner {
        owner = newAddress;
        erc20Contract.transferOwnership(newAddress);
    }

    //Should only be able to called by the credify platform
    function rewardCT(uint256 amt) public {
        erc20Contract.mint(msg.sender, amt);
    }

    function burnCT(address receipt, uint256 amt) public {
        erc20Contract.transferFrom(receipt, owner, amt); //Owner or replace with a burner address?
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