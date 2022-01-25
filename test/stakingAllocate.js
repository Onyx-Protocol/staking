const FakeToken = artifacts.require('FakeToken');
const Staking = artifacts.require('CHNStaking');
const { default: BigNumber } = require('bignumber.js');
const { assert } = require('chai');
const { ethers, waffle } = require('hardhat');

const BN = web3.utils.BN;
const {
  etherUnsigned,
  mineBlockNumber,
  advanceBlockTo,
  advanceBlock,
  advanceIncreaseBlock
} = require('./Ethereum');

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('Staking Contract', function (accounts) {
  let root = accounts[0];
  let a1 = accounts[1];
  let a2 = accounts[2];
  let a3 = accounts[3];
  let a4 = accounts[4];
  let a5 = accounts[5];
  let token;
  let staking;
  let initAmount = new BN("10000000000000000000000000");
  let periodAmount = new BN("250000000000000000000000");
  const REWARD_SCALE = 10 ** 18;
  let rewardPerBlock = new BigNumber('100000000000000000000');
  const bonus = new BigNumber('10');
  const timeBonus = new BigNumber('100');

  beforeEach(async () => {
    token = await FakeToken.new("10000000000000000000000000");
    const block = await ethers.provider.getBlock("latest");
    staking = await Staking.new(token.address, rewardPerBlock.toString(), block.number, block.number + timeBonus.toNumber(), bonus.toString());
  });

  it('create pool', async() => {
    await expectThrow(staking.add(100, token.address, 1, {from: a1}), "Ownable: caller is not the owner");
    await staking.add(100, token.address, 1, {from: root});
    const pool = await staking.poolInfo(0);
    assert(pool.stakeToken == token.address);
    assert(pool.lastRewardBlock == 4);
    assert(pool.accCHNPerShare == 0);
    assert(pool.totalAmountStake == 0);
  })

  it('staking', async() => {
    await staking.add(100, token.address, 1);
    const stakeAmount = "1000000000000000000";
    await token.mintForUser(initAmount, {from: a1});
    await token.approve(staking.address, initAmount, {from: a1});
    await staking.stake(0, stakeAmount, {from: a1});
    let totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == '0');
    await advanceIncreaseBlock(1);
    totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == rewardPerBlock.times(bonus).toFixed().toString());
    await advanceIncreaseBlock(10);
    totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == rewardPerBlock.times(bonus).times(11).toFixed().toString());
    
    await staking.stake(0, stakeAmount, {from: a1});
  })


  it('withdraw', async () => {
    await staking.add(100, token.address, 1);
    const stakeAmount = "1000000000000000000";
    await token.mintForUser(initAmount, {from: root});
    await token.mintForUser(initAmount, {from: a1});
    await token.transfer(staking.address, initAmount, {from: root});
    await token.approve(staking.address, initAmount, {from: a1});
    await staking.stake(0, stakeAmount, {from: a1});
    let totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == '0');
    await advanceIncreaseBlock(49);
    totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == rewardPerBlock.times(bonus).times(49).toFixed().toString());
    const oldAmount = await token.balanceOf(a1);
    await staking.withdraw(0, stakeAmount, {from: a1});
    let pendingReward = rewardPerBlock.times(bonus).times(50);
    totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == '0');
    let currentAmount = await token.balanceOf(a1);
    assert(pendingReward.plus(stakeAmount).plus(oldAmount).toFixed().toString() == currentAmount.toString());

  });

  it('emergencyWithdraw', async () => {
    await staking.add(100, token.address, 1);
    const stakeAmount = "1000000000000000000";
    await token.mintForUser(initAmount, {from: root});
    await token.mintForUser(initAmount, {from: a1});
    await token.transfer(staking.address, initAmount, {from: root});
    await token.approve(staking.address, initAmount, {from: a1});
    await staking.stake(0, stakeAmount, {from: a1});
    let totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == '0');
    await advanceIncreaseBlock(49);
    totalReward = await staking.pendingReward(0, a1);
    assert(totalReward.toString() == rewardPerBlock.times(bonus).times(49).toFixed().toString());
    const oldAmount = await token.balanceOf(a1);
    await staking.emergencyWithdraw(0, {from: a1});
    let currentAmount = await token.balanceOf(a1);
    assert(new BigNumber(stakeAmount).plus(oldAmount).toFixed().toString() == currentAmount.toString());

  });
});



function  assertEqual (val1, val2, errorStr) {
  val2 = val2.toString();
  val1 = val1.toString()
  assert(new BN(val1).should.be.a.bignumber.that.equals(new BN(val2)), errorStr);
}

function expectError(message, messageCompare) {
  messageCompare = "Error: VM Exception while processing transaction: reverted with reason string '" + messageCompare + "'";
  assert(message == messageCompare, 'Not valid message');
}

async function expectThrow(f1, messageCompare) {
  let check = false;
  try {
    await f1;
  } catch (e) {
    check = true;
    expectError(e.toString(), messageCompare)
  };

  if (!check) {
    assert(1 == 0, 'Not throw message');
  }
}

async function increaseTime(second) {
  await ethers.provider.send('evm_increaseTime', [second]); 
  await ethers.provider.send('evm_mine');
}