require('dotenv').config();

require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");

module.exports = {
  defaultNetwork: "matic",
  networks: {
    hardhat: {
    },
    matic: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      gas: 10000000
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      gas: 10000000
    }
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
  solidity: {
    version: "0.8.4",
    settings: {
      "optimizer": {
        "enabled": true,
        "runs": 1000
      },
      "outputSelection": {
        "*": {
          "*": [
            "evm.bytecode",
            "evm.deployedBytecode",
            "devdoc",
            "userdoc",
            "metadata",
            "abi"
          ]
        }
      },
      "libraries": {}
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 21
  },
  mocha: {
    timeout: 20000
  }
}
