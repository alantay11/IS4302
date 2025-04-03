const hre = require("hardhat");

async function main() {
  // Deploy the "Credential" contract
  const Credential = await hre.ethers.getContractFactory("Credential");
  const credential = await Credential.deploy();
  await credential.waitForDeployment();
  console.log("Credential deployed to:", await credential.getAddress());

  // Deploy the "Credify" contract
  const Credify = await hre.ethers.getContractFactory("Credify");
  const credify = await Credify.deploy();
  await credify.waitForDeployment();
  console.log("Credify deployed to:", await credify.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });