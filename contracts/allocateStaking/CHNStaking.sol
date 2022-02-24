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

    event Add(address indexed stakToken, uint256 indexed allocPoint);
    event Set(uint256 indexed pid, uint256 indexed allocPoint);
    event Stake(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, uint256 reward);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event ClaimRewardFromVault(address indexed userAddress, uint256 indexed pid);
    
    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    
    IERC20 public rewardToken;
    uint256 public rewardPerBlock;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) public poolTokens;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    uint256 public bonusEndBlock;
    uint256 public BONUS_MULTIPLIER;
    address public rewardVault;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (uint256 => mapping (address => mapping (uint32 => Checkpoint))) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (uint256 => mapping (address => uint32)) public numCheckpoints;

    modifier validatePoolByPid(uint256 _pid) {
        require(_pid < poolInfo.length, "Pool does not exist");
        _;
    }

    function initialize(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _multiplier,
        address _rewardVault
    ) public initializer {
        require(_rewardVault != address(0) && address(_rewardToken) != address(0), "Zero address validation");
        require(_startBlock < _bonusEndBlock, "Start block lower than bonus end block");
        require(_rewardPerBlock < _rewardToken.totalSupply(), "Reward per block less than token total supply");
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

    // Add a new stake to the pool. Can only be called by the Timelock and DAO.
    // XXX DO NOT add the same stake token more than once. Rewards will be messed up if you do.
    // This function can be only called by Timelock and DAO with voting power
    function add(
        uint256 _allocPoint,
        IERC20 _stakeToken
    ) public onlyOwner {
        require(!poolTokens[address(_stakeToken)], "Stake token already exist");
        massUpdatePools();
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolTokens[address(_stakeToken)] = true;
        poolInfo.push(
            PoolInfo({
                stakeToken: _stakeToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accCHNPerShare: 0,
                totalAmountStake: 0
            })
        );
        emit Add(address(_stakeToken), _allocPoint);
    }

    // Update the given pool's SUSHI allocation point. Can only be called by the Timelock and DAO.
    // This function can be only called by Timelock and DAO with voting power
    function set(
        uint256 _pid,
        uint256 _allocPoint
    ) public onlyOwner validatePoolByPid(_pid) {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        emit Set(_pid, _allocPoint);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        require(_from >= startBlock, "from block number bigger than start block");
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
        validatePoolByPid(_pid)
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
    function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
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

    function _moveDelegates(uint256 _pid, address dstRep, uint256 amount, bool stake) internal {
        if (amount > 0) {
            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[_pid][dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[_pid][dstRep][dstRepNum - 1].votes : 0;
                if (stake) {
                    uint256 dstRepNew = dstRepOld.add(amount);
                    _writeCheckpoint(_pid, dstRep, dstRepNum, dstRepOld, dstRepNew);
                } else {
                    uint256 dstRepNew = dstRepOld.sub(amount);
                    _writeCheckpoint(_pid, dstRep, dstRepNum, dstRepOld, dstRepNew);
                }
            }
        }
    }

    // Only support non-deflationary tokens staking
    function stake(uint256 _pid, uint256 _amount) public validatePoolByPid(_pid) {
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

        _moveDelegates(_pid, msg.sender, _amount, true);
        emit Stake(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public validatePoolByPid(_pid) {
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

        // Remove delegates from staking user
        _moveDelegates(_pid, msg.sender, _amount, false);
        emit Withdraw(msg.sender, _pid, _amount, 0);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public validatePoolByPid(_pid) {
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

    function claimRewardFromVault(address userAddress, uint256 pid) public validatePoolByPid(pid) returns (uint256) {
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
        emit ClaimRewardFromVault(userAddress, pid);
        return pending;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(uint256 _pid, address account, uint blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "Comp::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[_pid][account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[_pid][account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[_pid][account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[_pid][account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[_pid][account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[_pid][account][lower].votes;
    }

    function _writeCheckpoint(uint256 _pid, address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
      uint32 blockNumber = safe32(block.number, "Comp::_writeCheckpoint: block number exceeds 32 bits");

      if (nCheckpoints > 0 && checkpoints[_pid][delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
          checkpoints[_pid][delegatee][nCheckpoints - 1].votes = newVotes;
      } else {
          checkpoints[_pid][delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
          numCheckpoints[_pid][delegatee] = nCheckpoints + 1;
      }

      emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
    
    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }
}
