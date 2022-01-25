require("dotenv").config();
const { deployments, ethers, artifacts } = require("hardhat");

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const { deploy, execute } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log( {deployer} );

  const rewardVault = await deploy("CHNReward", {
    from: deployer,
    args: [process.env.CHN_ADDRESS],
    log: true,
  });

  await deploy("CHNStaking", {
    from: deployer,
    log: true,
    proxy: {
      proxyContract: "OptimizedTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            process.env.CHN_ADDRESS,
            process.env.REWARD_PER_BLOCK,
            process.env.START_BLOCK,
            process.env.END_BONUS_BLOCK,
            process.env.MULTIPLIER,
            rewardVault.address
          ],
        }
      },
    },
  });

};

module.exports = func;

module.exports.tags = ['deploy-verify'];

async function sleep(timeout) {
  return new Promise((resolve, reject) => {
    setTimeout(() => {
      resolve();
    }, timeout);
  });
}