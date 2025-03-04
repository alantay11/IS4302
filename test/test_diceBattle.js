const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DiceBattle", function () {
  let Dice, DiceBattle;
  let dice, diceBattle;
  let owner, player1, player2, others;

  beforeEach(async function () {
    [owner, player1, player2, ...others] = await ethers.getSigners(); // Get signers HERE

    // deploy Dice
    Dice = await ethers.getContractFactory("Dice");
    dice = await Dice.deploy();
    await dice.waitForDeployment();

    // deploy DiceBattle with DiceAddress
    DiceBattle = await ethers.getContractFactory("DiceBattle");
    diceBattle = await DiceBattle.deploy(await dice.getAddress());
    await diceBattle.waitForDeployment();

  });

  // Test 1 Verify deploy
  it("Should deploy Dice and DiceBattle contracts successfully", async function () {
    expect(await dice.getAddress()).to.be.properAddress;
    expect(await diceBattle.getAddress()).to.be.properAddress;
  });

  // Test 2 Add dices by different player
  it("Should create dice successfully", async function () {
    // Player 1 add dice
    const tx1 = await dice.connect(player1).add(6, 1, { value: ethers.parseEther("0.1") });
    await tx1.wait();

    // Player 2 add dice
    const tx2 = await dice.connect(player2).add(30, 1, { value: ethers.parseEther("0.1") });
    await tx2.wait();

    const diceCount = await dice.numDices();
    expect(diceCount).to.not.equal(0);
  });

  // Test 3 Add dice without supplying ether
  it("Should not create dice without supplying ether", async function () {
    // Player 1 add dice without ether
    await expect(dice.connect(player1).add(6, 1)).to.be.revertedWith("at least 0.01 ETH is needed to spawn a new dice");
  });

  // Test 4 Transfer a dice to the DiceBattle contract
  it("Should transfer a dice to the DiceBattle contract", async function () {
    // Create dice first - this will be diceId 0
    await dice.connect(player1).add(6, 1, { value: ethers.parseEther("0.1") });

    // transfer dice on diceBattle contract manually
    await dice.connect(player1).transfer(0, await diceBattle.getAddress());

    // Verify ownership transferred to market
    const ownerOfDice = await dice.getOwner(0);
    expect(ownerOfDice).to.equal(await diceBattle.getAddress());
  });

  // Test 5 Test opponent needs to be matched for dicebattle to execute
  it("Should not execute battle if opponents not matched", async function () {
    // Create new dice - this will be diceId 0
    await dice.connect(player1).add(3, 1, { value: ethers.parseEther("0.1") });
    await dice.connect(player2).add(30, 1, { value: ethers.parseEther("0.1") });

    // transfer dice on diceBattle contract manually
    await dice.connect(player1).transfer(0, await diceBattle.getAddress());
    //await dice.connect(player2).transfer(1, await diceBattle.getAddress());

    // battle should revert as opponents not matched
    await expect(diceBattle.connect(player1).battle(0, 1)).to.be.revertedWith("Each player must accept a battle with the other");
  });

  // Test 6 Test dicebattle working, i.e., the die are distributed as designed after the battle
  it("Should distribute dice as designed after the battle", async function () {
   // Create new dice - this will be diceId 0
   await dice.connect(player1).add(3, 1, { value: ethers.parseEther("0.1") });
   await dice.connect(player2).add(30, 1, { value: ethers.parseEther("0.1") });

   // transfer dice on diceBattle contract manually
   await dice.connect(player1).transfer(0, await diceBattle.getAddress());
   await dice.connect(player2).transfer(1, await diceBattle.getAddress());

  // both players setBattlePair
   await diceBattle.connect(player1).setBattlePair(0, player2.getAddress());
   await diceBattle.connect(player2).setBattlePair(1, player1.getAddress());

   // battle should work
   await diceBattle.connect(player1).battle(0, 1);

   const player1Number = await dice.connect(player1).getDiceNumber(0);
   const player2Number = await dice.connect(player2).getDiceNumber(1);

   if (player1Number > player2Number) {
    expect(await dice.getOwner(0)).to.equal(await player1.getAddress());
    expect(await dice.getOwner(1)).to.equal(await player1.getAddress());
  } else if (player1Number < player2Number) {
    expect(await dice.getOwner(0)).to.equal(await player2.getAddress());
    expect(await dice.getOwner(1)).to.equal(await player2.getAddress());
  } else {
    expect(await dice.getOwner(0)).to.equal(await player1.getAddress());
    expect(await dice.getOwner(1)).to.equal(await player2.getAddress());
  }
  });
});
