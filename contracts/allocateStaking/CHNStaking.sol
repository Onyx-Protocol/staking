// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CHNStaking is OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingTokenReward;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 stakeToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accCHNPerShare;
        uint256 totalAmountStake;
    }

    event Stake(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, uint256 reward);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    IERC20 public rewardToken;
    uint256 public rewardPerBlock;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    uint256 public bonusEndBlock;
    uint256 public BONUS_MULTIPLIER;
    address public rewardVault;

    function initialize(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _multiplier,
        address _rewardVault
    ) public initializer {
        __Ownable_init();
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
        BONUS_MULTIPLIER = _multiplier;
        rewardVault = _rewardVault;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getStakingAmount(uint256 pid, address user) public view returns (uint256) {
        UserInfo memory info = userInfo[pid][user];
        return info.amount;
    }

    // Add a new stake to the pool. Can only be called by the owner.
    // XXX DO NOT add the same stake token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _stakeToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                stakeToken: _stakeToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accCHNPerShare: 0,
                totalAmountStake: 0
            })
        );
    }

    // Update the given pool's SUSHI allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCHNPerShare = pool.accCHNPerShare;
        uint256 supply = pool.totalAmountStake;
        if (block.number > pool.lastRewardBlock && supply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 reward =
                multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accCHNPerShare = accCHNPerShare.add(
                reward.mul(1e12).div(supply)
            );
        }
        return user.amount.mul(accCHNPerShare).div(1e12).add(user.pendingTokenReward).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 supply = pool.totalAmountStake;
        if (supply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 reward =
            multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        pool.accCHNPerShare = pool.accCHNPerShare.add(
            reward.mul(1e12).div(supply)
        );
        pool.lastRewardBlock = block.number;
    }

    function stake(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accCHNPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            user.pendingTokenReward = user.pendingTokenReward.add(pending);
        }
        pool.totalAmountStake = pool.totalAmountStake.add(_amount);
        pool.stakeToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accCHNPerShare).div(1e12);
        emit Stake(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accCHNPerShare).div(1e12).sub(
                user.rewardDebt
            );
        // pending = pending.add(user.pendingTokenReward);
        // pool.stakeToken.safeTransfer(address(msg.sender), pending);
        user.pendingTokenReward = user.pendingTokenReward + pending;
        user.amount = user.amount.sub(_amount);
        pool.totalAmountStake = pool.totalAmountStake.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accCHNPerShare).div(1e12);
        pool.stakeToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount, 0);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 userAmount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.pendingTokenReward = 0;
        pool.totalAmountStake = pool.totalAmountStake.sub(userAmount);
        pool.stakeToken.safeTransfer(address(msg.sender), userAmount);
        emit EmergencyWithdraw(msg.sender, _pid, userAmount);
    }

    function claimRewardFromVault(address userAddress, uint256 pid) public returns (uint256) {
        require(msg.sender == rewardVault, "Ownable: only reward vault");
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][userAddress];
        updatePool(pid);
        uint256 pending =
            user.amount.mul(pool.accCHNPerShare).div(1e12).sub(
                user.rewardDebt
            );
        pending = pending + user.pendingTokenReward;
        user.pendingTokenReward = 0;
        user.rewardDebt = user.amount.mul(pool.accCHNPerShare).div(1e12);
        return pending;
    }
}
