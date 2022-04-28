require("dotenv").config();
require("hardhat-deploy");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("./tasks/compileOne.js");
require("hardhat-gas-reporter");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  namedAccounts: {
    deployer: 0,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    rinkeby: {
      url: process.env.RPC_URL,
      accounts: [process.env.ACC_PRIVATE_KEY],
    },
    bsclocal: {
      url: "http://127.0.0.1:8885",
      accounts: [process.env.ACC_PRIVATE_KEY],
    },
    bsctestnet: {
      url: "https://data-seed-prebsc-2-s3.binance.org:8545/",
      accounts: [process.env.ACC_PRIVATE_KEY],
    },
    bscmainnet: {
      url: process.env.RPC_URL,
      accounts: [process.env.ACC_PRIVATE_KEY],
      chainId: 56
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          evmVersion: "istanbul",
          optimizer: {
            enabled: true,
            runs: 1000000,
            details: { yul: true, deduplicate: true, cse: true, constantOptimizer: true },
          },
        },
      },
      {
        version: "0.8.3",
        settings: {
          evmVersion: "istanbul",
          optimizer: {
            enabled: true,
            runs: 1000000,
            details: {
              yul: true,
              deduplicate: true,
              cse: true,
              constantOptimizer: true,
            },
          },
        },
      },
      {
        version: "0.8.0",
        settings: {
          evmVersion: "istanbul",
          optimizer: {
            enabled: true,
            runs: 1000000,
            details: {
              yul: true,
              deduplicate: true,
              cse: true,
              constantOptimizer: true,
            },
          },
        },
      },
    ],
  },
};
