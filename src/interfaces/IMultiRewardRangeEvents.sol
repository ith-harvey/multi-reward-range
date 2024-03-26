// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IMultiRewardRangeEvents {

    event ClaimRewards(address indexed owner, address indexed ajnaPool, uint256 indexed tokenId, uint256[] epochsClaimed, uint256 amount);
    event MoveStakedLiquidity(uint256 tokenId, uint256[] fromIndexes, uint256[] toIndexes);
    event Stake(address indexed owner, address indexed ajnaPool, uint256 indexed tokenId);
    event UpdateExchangeRates(address indexed caller, address indexed ajnaPool, uint256[] indexesUpdated, uint256 rewardsClaimed);
    event Unstake(address indexed owner, address indexed ajnaPool, uint256 indexed tokenId);
    event RewardPaid(address owner, address rewardsToken, uint256 rewardsPaid);
    event RewardAdded(uint256 reward);
    event Recovered(address tokenAddress, uint256 tokenAmount);
    event RewardsDurationUpdated(address _rewardsToken, uint256 newDuration);
    event RangeExpanded(uint16 lowerBound, uint16 upperBound);

}