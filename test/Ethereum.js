"use strict";

const BigNum = require('bignumber.js');
const { ethers } = require('hardhat');

function etherUnsigned(num) {
  return new BigNum(num).toFixed();
}

async function increaseTime(seconds) {
  await rpc({ method: 'evm_increaseTime', params: [seconds] });
  return rpc({ method: 'evm_mine' });
}

async function setTime(seconds) {
  await rpc({ method: 'evm_setTime', params: [new Date(seconds * 1000)] });
}

async function freezeTime(seconds) {
  await rpc({ method: 'evm_freezeTime', params: [seconds] });
  return rpc({ method: 'evm_mine' });
}

async function mineBlockNumber(blockNumber) {
  // return rpc({method: 'evm_mineBlockNumber', params: [blockNumber]});
  const current = await ethers.provider.getBlockNumber();
  await ethers.provider.send('evm_mine', [blockNumber + current]);
}

async function advanceBlock() {
  return ethers.provider.send("evm_mine", []);
}
async function advanceBlockTo(blockNumber) {
  for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
    await advanceBlock();
  }
}

async function advanceIncreaseBlock(blockNumber) {
  const current = await ethers.provider.getBlockNumber();
  const to = blockNumber + current;
  for (let i = await ethers.provider.getBlockNumber(); i < to; i++) {
    await advanceBlock();
  }
}


module.exports = {
  etherUnsigned,
  freezeTime,
  increaseTime,
  setTime,
  mineBlockNumber,
  advanceBlockTo,
  advanceBlock,
  advanceIncreaseBlock
};
