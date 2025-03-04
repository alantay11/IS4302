const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DiceMarket", function () {
  let Dice, DiceMarket;
  let dice, diceMarket;
  let owner, player1, player2, others;

  beforeEach(async function () {
    [owner, player1, player2, ...others] = await ethers.getSigners(); // Get signers HERE

    // deploy Dice
    Dice = await ethers.getContractFactory("Dice");
    dice = await Dice.deploy();
    await dice.waitForDeployment();

    // deploy DiceMarket with commission fee
    DiceMarket = await ethers.getContractFactory("DiceMarket");
    diceMarket = await DiceMarket.deploy(await dice.getAddress(), ethers.parseEther("0.01"));
    await diceMarket.waitForDeployment();
  });

  // Test 1 Verify deploy
  it("Should deploy Dice and DiceMarket contracts successfully", async function () {
    expect(await dice.getAddress()).to.be.properAddress;
    expect(await diceMarket.getAddress()).to.be.properAddress;
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

  // Test 3 Transfer a dice to the DiceMarket contract
  it("Should transfer a dice to the DiceMarket contract", async function () {
    // Create dice first - this will be diceId 0
    await dice.connect(player1).add(6, 1, { value: ethers.parseEther("0.1") });

    // transfer dice on diceMarkt contract manually
    await dice.connect(player1).transfer(0, await diceMarket.getAddress());

    // Verify ownership transferred to market
    const ownerOfDice = await dice.getOwner(0);
    expect(ownerOfDice).to.equal(await diceMarket.getAddress());
  });

  // Test 4 Owner can list
  it("Should list a dice in the market", async function () {
    // Create new dice - this will be diceId 0
    await dice.connect(player1).add(3, 1, { value: ethers.parseEther("0.1") });

    // transfer dice on diceMarket contract manually
    await dice.connect(player1).transfer(0, await diceMarket.getAddress());

    // List the dice (this will also transfer ownership)
    await diceMarket.connect(player1).list(0, ethers.parseEther("1"));
    const listedPrice = await diceMarket.checkPrice(0);
    expect(listedPrice).to.equal(ethers.parseEther("1"));
  });
});
