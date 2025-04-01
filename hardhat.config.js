require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  localhost: {
    url: "http://127.0.0.1:8545", // local blockchain (hardhat)
  },
  settings: {
    viaIR: true, // Enable the IR pipeline
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
};
