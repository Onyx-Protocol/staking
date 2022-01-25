// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface CHNStakingInterface {
    function claimRewardFromVault(address userAddress, uint256 pid) external returns (uint256);
}

contract CHNReward is Ownable {
    using SafeERC20 for IERC20;

    event Claim(address indexed user, uint256 indexed pid, uint256 reward);
    event GrantDAO(address indexed user, uint256 amount);

    IERC20 public rewardToken;
    CHNStakingInterface public staking;

    constructor(IERC20 _rewardToken) Ownable() {
        rewardToken = _rewardToken;
    }

    function changeStakingAdderss(address _staking) public onlyOwner {
        staking = CHNStakingInterface(_staking);
    }

    function claimReward(uint256 pid) public {
        uint256 rewardAmount = staking.claimRewardFromVault(msg.sender, pid);
        rewardToken.safeTransfer(address(msg.sender), rewardAmount);
        emit Claim(msg.sender, pid, rewardAmount);
    }

    function grantDAO(address user, uint256 amount) public onlyOwner {
        rewardToken.safeTransfer(user, amount);
        emit GrantDAO(user, amount);
    }
}
