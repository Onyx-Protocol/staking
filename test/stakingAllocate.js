const { ethers, upgrades } = require('hardhat');
const { utils } = ethers;
const { expect } = require("chai");

describe('Staking Contract', function () {
  let alice;
  let bob;
  let carol;
  let chn;
  let staking;
  let rewardVault;
  let uni;
  const bonusMultiplier = 10;
  const rewardPerBlock = utils.parseEther("100");

  before(async () => {
    const signers = await ethers.getSigners();
    alice = signers[1];
    bob = signers[2];
    carol = signers[3];
    this.ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    this.RewardVault = await ethers.getContractFactory("CHNReward");
    this.Staking = await ethers.getContractFactory("CHNStaking");
    
  })
  beforeEach(async () => {
    chn = await this.ERC20Mock.deploy("Chain", "CHN", utils.parseEther("10000000000000000000000000"));
    await chn.deployed();

    uni = await this.ERC20Mock.deploy("UNI", "UNI", utils.parseEther("10000000000000000000000000"));
    await uni.deployed();
    await uni.transfer(alice.address, utils.parseEther("1000"));
    await uni.transfer(bob.address, utils.parseEther("1000"))
    await uni.transfer(carol.address, utils.parseEther("1000"));

    rewardVault = await this.RewardVault.deploy(chn.address);
    await rewardVault.deployed();

    staking = await upgrades.deployProxy(this.Staking, [chn.address, rewardPerBlock, 0, 1000, bonusMultiplier, rewardVault.address])
    await staking.deployed();

    rewardVault.changeStakingAddress(staking.address);
    await chn.transfer(rewardVault.address, utils.parseEther("100000"));
  });
  
  context("RewardVault", () => {
    beforeEach(async() => {

    })

    it("only owner should change staking address", async() => {
      await expect(rewardVault.connect(alice).changeStakingAddress(bob.address)).to.be.reverted;
      await rewardVault.changeStakingAddress(bob.address);
      expect(await rewardVault.staking()).to.equal(bob.address);
    })

    it("only owner should grant dao", async() => {
      await expect(rewardVault.connect(alice).grantDAO(bob.address, utils.parseEther("10"))).to.be.reverted;
      await rewardVault.grantDAO(bob.address, utils.parseEther("10"));
      expect(await chn.balanceOf(bob.address)).to.equal(utils.parseEther("10"));
    })
  })

  it('create pool', async() => {
    await expect(staking.connect(alice).add(100, uni.address)).to.be.revertedWith("Ownable: caller is not the owner")
    await staking.add(100, uni.address);
    const pool = await staking.poolInfo(0);
    expect(pool.stakeToken).to.equal(uni.address);
    expect(pool.totalAmountStake).to.equal(0);
    expect(pool.accCHNPerShare).to.equal(0);
  })

  it('staking', async() => {
    await staking.add(100, uni.address);
    await uni.connect(alice).approve(staking.address, utils.parseEther("100"));
    await staking.connect(alice).stake(0, utils.parseEther("100"));
    expect(await uni.balanceOf(alice.address)).to.equal(utils.parseEther("900")) // 1000 - 100
    expect(await staking.pendingReward(0, alice.address)).to.equal("0");
    await mineBlocks(1);
    expect(await staking.pendingReward(0, alice.address)).to.equal(utils.parseEther("1000"));
    await mineBlocks(10);
    expect(await staking.pendingReward(0, alice.address)).to.equal(utils.parseEther("11000"));
    await staking.connect(alice).withdraw(0, utils.parseEther("100"));
    expect(await uni.balanceOf(alice.address)).to.equal(utils.parseEther("1000"))
    await rewardVault.connect(alice).claimReward(0);
    expect(await chn.balanceOf(alice.address)).to.equal(utils.parseEther("12000"));
  })
});

async function mineBlocks(n) {
  for (let index = 0; index < n; index++) {
    await ethers.provider.send('evm_mine', []);
  }
}