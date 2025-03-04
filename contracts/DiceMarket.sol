// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./Dice.sol";

contract DiceMarket {

    Dice diceContract;
    uint256 public commissionFee;
    address _owner = msg.sender;
    mapping(uint256 => uint256) listPrice;

     constructor(Dice diceAddress, uint256 fee)  {
        diceContract = diceAddress;
        commissionFee = fee;
        _owner = msg.sender; // Assign owner in the constructor
    }


    //list a dice for sale. Price needs to be >0
    function list(uint256 id, uint256 price) public {
       require(price >= 0, "Listing price must be greater than 0");
       require(msg.sender == diceContract.getPrevOwner(id));
       listPrice[id] = price;
    }

    function unlist(uint256 id) public {
       require(listPrice[id] != 0, "Dice is not listed");
       require(msg.sender == diceContract.getPrevOwner(id));
       diceContract.transfer(id, msg.sender);
       listPrice[id] = 0;
  }

    // get price of dice
    function checkPrice(uint256 id) public view returns (uint256) {
       return listPrice[id];
 }

    // Buy the dice at the requested price
    function buy(uint256 id) public payable {
    require(listPrice[id] != 0, "Item is not listed"); // Ensure item is listed
    require(msg.value >= listPrice[id] + commissionFee, "Insufficient payment"); // Ensure enough payment
    address payable recipient = payable(diceContract.getPrevOwner(id));
    recipient.transfer(listPrice[id]); // Transfer (price - commission fee) to real owner
    diceContract.transfer(id, msg.sender);
    }


    function getContractOwner() public view returns(address) {
       return _owner;
    }

    function withDraw() public {
        if(msg.sender == _owner)
            payable(msg.sender).transfer(address(this).balance);
    }
}
