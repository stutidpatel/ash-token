require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
        chainId: 31337, // Hardhat's default chain ID for local network
    },
    localhost: {
        url: "http://127.0.0.1:8545", // URL of the local node
        // Accounts and gas configuration are not needed here for `localhost`
    },
},
};
