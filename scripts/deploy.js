const hre = require("hardhat");

async function main() {
  // Deploy the "Dice" contract
  const Dice = await hre.ethers.getContractFactory("Dice");
  const dice = await Dice.deploy();
  await dice.waitForDeployment();
  console.log("Dice deployed to:", await dice.getAddress());

  // Deploy the "DiceMarket" contract, passing the Dice address to its constructor
  const DiceMarket = await hre.ethers.getContractFactory("DiceMarket");
  const diceMarket = await DiceMarket.deploy(await dice.getAddress(), "10000000000000000");
  await diceMarket.waitForDeployment();
  console.log("DiceMarket deployed to:", await dice.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });