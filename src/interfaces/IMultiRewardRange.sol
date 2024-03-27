// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IMultiRewardRange {

    /**
     * @notice Add a new reward token to the contract
     * @param rewardsToken_       Address of the reward token
     * @param rewardsDistributor_ Address of the rewards distributor
     * @param rewardsDuration_    Duration of the rewards period
    */
    function addReward(address rewardsToken_, address rewardsDistributor_, uint256 rewardsDuration_) external;

    /**
     * @notice Expand the reward range 
     * @param lowerBound_ lower bound, the higher price of the reward range
     * @param upperBound_ upper bound, the lower price of the reward range
     */
    function expandRewardRange(uint16 lowerBound_, uint16 upperBound_) external;
    
    /**
     * @notice Notify reward amount for a specific reward token
     * @param rewardsToken_ Address of the reward token
     * @param reward_       Amount of reward to be given
    */
    function notifyRewardAmount(address rewardsToken_, uint256 reward_) external;

    /**
     * @notice Recover ERC20 tokens sent to this contract by mistake
     * @param tokenAddress_ Address of the token to recover
     * @param tokenAmount_  Amount of tokens to recover
    */
    function recoverERC20(address tokenAddress_, uint256 tokenAmount_) external;

    /**
     * @notice set a new duration for rewards distribution
     * @param rewardsToken_    Address of the reward token 
     * @param rewardsDuration_ New duration of the rewards period
    */
    function setRewardsDuration(address rewardsToken_, uint256 rewardsDuration_) external;

    /**
     * @notice Set rewards distributor for a specific reward token 
     * @param rewardsToken_       Address of the reward token
     * @param rewardsDistributor_ Address of the new rewards distributor
    */
    function setRewardsDistributor(address rewardsToken_, address rewardsDistributor_) external;

    /**
     * @notice Stake a ERC20 LP NFT to earn rewards
     * @param tokenId_ ID of the NFT
    */
    function stake(uint256 tokenId_) external;

    /**
     * @notice Unstake a ERC20 LP NFT, not withdrawing rewards
     * @param tokenId_ ID of the NFT
    */
    function unstake(uint256 tokenId_) external;

    /**
     * @notice Collect staking rewards of all reward tokens
     * @param tokenId_ ID of the NFT
    */
    function getReward(uint256 tokenId_) external;

    /**
     * @notice Exit staking and claim rewards
     * @param tokenId_ ID of the NFT
    */
    function exit(uint256 tokenId_) external;

    /**
     * @notice Get total LP accross all positions
     * @return _totalSupply LP accross all positions in the staking contract
    */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Get the stakeInfo for a LP NFT token
     * @param tokenId_ ID of the NFT
     * @return owner owner of the LP NFT
     * @return lastUpdated timestamp of last time staking position was updated
     * @return lps total LP associated with this LP NFT
    */
    function getStakeInfo(uint256 tokenId_) external view returns (address, uint256, uint256);

    /**
     * @notice Calculates earned token rewards associated with the staked LP NFT
     * @param tokenId_      ID of the staked LP token  
     * @param rewardsToken_ Address of the reward token
     * @return earned rewards amount
    */ 
    function earned(uint256 tokenId_, address rewardsToken_) external view returns (uint256);

    /**
     * @notice Get the reward per staked token
     * @param rewardsToken_ Address of the reward token
     * @return Reward per staked token
    */
    function rewardPerToken(address rewardsToken_) external view returns (uint256);

    /**
     * @notice Get the last time reward is applicable
     * @param rewardsToken_ Address of the reward token
     * @return lastTimeRewardApplicable timestamp of last time reward is applicable
    */
    function lastTimeRewardApplicable(address rewardsToken_) external view returns (uint256);
    
    /**
     * @notice Get the last time reward is applicable
     * @param rewardsToken_ Address of the reward token 
     * @return lastTimeRewardApplicable timestamp of last time reward is applicable
    */
    function getRewardForDuration(address rewardsToken_) external view returns (uint256);

    /**
     * @notice Get stake rewards info for a token ID and reward token
     * @param tokenId_      ID of the staked LP token
     * @param rewardsToken_ Address of the reward token
     * @return owed rewards amount, userRewardPerTokenStoredPaid  
    */
    function getStakeRewardsInfo(uint256 tokenId_, address rewardsToken_) external view returns (uint256, uint256);
    
    /**
     * @notice Get stake reward range for the contract
     * @return upperBound upperBound, lower price of the reward range
     * @return lowerBound lowerBound, higher price of the reward range
    */
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