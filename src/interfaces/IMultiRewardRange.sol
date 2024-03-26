// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IMultiRewardRange {
    // External functions
    function addReward(address rewardsToken_, address rewardsDistributor_, uint256 rewardsDuration_) external;
    function expandRewardRange(uint16 lowerBound_, uint16 upperBound_) external;
    function notifyRewardAmount(address rewardsToken_, uint256 reward_) external;
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external;
    function setRewardsDuration(address rewardsToken_, uint256 rewardsDuration_) external;
    function setRewardsDistributor(address rewardsToken_, address rewardsDistributor_) external;
    function stake(uint256 tokenId_) external;
    function unstake(uint256 tokenId_) external;
    function getReward(uint256 tokenId_) external;
    function exit(uint256 tokenId_) external;
    function totalSupply() external view returns (uint256);
    function getStakeInfo(uint256 tokenId_) external view returns (address, uint256, uint256);
    function earned(uint256 tokenId_, address rewardsToken_) external view returns (uint256);
    function rewardPerToken(address rewardsToken_) external view returns (uint256);
    function lastTimeRewardApplicable(address rewardsToken_) external view returns (uint256);
    function getRewardForDuration(address rewardsToken_) external view returns (uint256);
    function getStakeRewardsInfo(uint256 tokenId_, address rewardsToken_) external view returns (uint256, uint256);
    function getRewardRange() external view returns (uint16, uint16);

        /**
     *  @notice User attempted to claim rewards multiple times.
     */
    error AlreadyClaimed();

    /**
     *  @notice User attempted to claim rewards for an epoch that is not yet available.
     */
    error EpochNotAvailable();

    /**
     *  @notice Insufficient Token Balance in contract to transfer rewards
     */
    error InsufficientLiquidity();

    /**
     *  @notice User provided move index params that didn't match in size.
     */
    error MoveStakedLiquidityInvalid();

    /**
     * @notice User attempted to update exchange rates for a pool that wasn't deployed by an `Ajna` factory.
     */
    error NotAjnaPool();

    /**
     *  @notice User attempted to interact with an `NFT` they aren't the owner of.
     */
    error NotOwnerOfDeposit();

    /**
     *  @notice Can't deploy with `Ajna` token or position manager address `0x`.
     */
    error DeployWithZeroAddress();
}