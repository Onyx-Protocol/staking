require("dotenv").config();
require("hardhat-deploy");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require('@openzeppelin/hardhat-upgrades');
require("./tasks/compileOne.js");
require("hardhat-gas-reporter");
require("solidity-coverage");

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
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,

      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },
    bsclocal: {
      url: "http://127.0.0.1:8885",
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    bsctestnet: {
      url: `https://bsc.getblock.io/testnet/?api_key=/${process.env.GETBLOCK_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
    bsc: {
      url: `https://bsc.getblock.io/mainnet/?api_key=/${process.env.GETBLOCK_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
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
