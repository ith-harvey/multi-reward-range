// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import { IERC20 }    from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IERC721 }   from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { SafeMath }  from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import { Math }      from '@openzeppelin/contracts/utils/math/Math.sol';

import { Pausable }        from  '@openzeppelin/contracts/security/Pausable.sol';
import { Ownable }         from  '@openzeppelin/contracts/access/Ownable.sol';
import { ReentrancyGuard } from  '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import { Maths }            from '@ajna-core/libraries/internal/Maths.sol';
import { IPool }            from '@ajna-core/interfaces/pool/IPool.sol';
import { IPositionManager } from '@ajna-core/interfaces/position/IPositionManager.sol';
import { PoolInfoUtils }    from '@ajna-core/PoolInfoUtils.sol';

import { IMultiRewardRange }       from './interfaces/IMultiRewardRange.sol';
import { IMultiRewardRangeEvents } from './interfaces/IMultiRewardRangeEvents.sol';

/**
 *  @title  MultiRewardRange (staking) contract
 *  @notice Pool lenders can optionally mint `NFT` that represents their positions.
 *          The Rewards contract allows pool lenders with positions `NFT` to stake and earn ERC20 tokens. 
 *          Lenders with `NFT`s can:
 *          - `stake` token
 *          - `getReward`
 *          - `unstake` token
 *          - `exit` getting rewards and unstaking token
 */
contract MultiRewardRange is IMultiRewardRange, IMultiRewardRangeEvents, ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /*********************/
    /*** State Structs ***/
    /*********************/

    /// @dev Struct holding stake info state.
    struct StakeInfo {
        uint256 lastUpdated;                    // last epoch the stake claimed rewards
        address owner;                          // owner of the LP NFT
        uint256 lps;                            // total LP staked
        mapping(address => RewardState) rewards;
    }

    struct RewardState {
        uint256 owed;                         // rewards earned by the staker
        uint256 userRewardPerTokenStoredPaid; // rewards to be claimed by the staker
    }

    struct Reward {
        address rewardsDistributor;
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    /***********************/
    /*** State Variables ***/
    /***********************/

    /// @dev total LP staked accross the reward range
    uint256 public totalSupply;

    /// @dev bounds that determine the reward range
    uint256 public lowerBound;
    uint256 public upperBound;

    address[] public rewardTokens;
    /// @dev Mapping `tokenID => Stake info`.
    mapping(uint256 => StakeInfo) internal _stakes;
    /// @dev Mapping `rewardsToken => Reward data`.
    mapping(address => Reward) public rewardData;

    /******************/
    /*** Immutables ***/
    /******************/

    /// @dev The `Pool` contract
    IPool public immutable ajnaPool;
    /// @dev The `PositionManager` contract
    IPositionManager public immutable positionManager;
    /// @dev the `PoolInfoUtils` contract
    PoolInfoUtils    public poolUtils = new PoolInfoUtils();


    /*******************/
    /*** Constructor ***/
    /*******************/

    /**
     *  @notice Deploys the RewardsManager contract.
     *  @param owner_ Owner
     *  @param positionManager_ Address of the PositionManager contract.
     *  @param ajnaPool_ Address of the Ajna Pool contract.
     *  @param positionManager_ Address of the Ajna Pool contract.
     *  @param lowerBound_ lowerBound_ the higher price in reward range.
     *  @param upperBound_ upperBound_ the lower price in reward range.
     */
     
    constructor(
        address owner_,
        IPool ajnaPool_,
        IPositionManager positionManager_,
        uint256 lowerBound_,
        uint256 upperBound_
        ) {
        require (
            owner_ != address(0) || address(positionManager_) != address(0) || address(ajnaPool_) != address(0)
        );
        // indexes and prices are flipped in ajna meaning the lowerBound is actually the higher price
        require(upperBound_ > lowerBound_);
        require(upperBound_ > 0 && upperBound_ < 7388);
        require(lowerBound_ > 0 && lowerBound_ < 7388);

        positionManager = positionManager_;
        ajnaPool        = ajnaPool_;

        upperBound = upperBound_;
        lowerBound = lowerBound_;
    }

    /**
     * @notice Add a new reward token to the contract
     * @param rewardsToken_ Address of the reward token
     * @param rewardsDistributor_ Address of the rewards distributor
     * @param rewardsDuration_ Duration of the rewards period
    */
    function addReward(
        address rewardsToken_,
        address rewardsDistributor_,
        uint256 rewardsDuration_
    ) public onlyOwner {
        require(rewardData[rewardsToken_].rewardsDuration == 0);
        rewardTokens.push(rewardsToken_);
        rewardData[rewardsToken_].rewardsDistributor = rewardsDistributor_;
        rewardData[rewardsToken_].rewardsDuration    = rewardsDuration_;
    }

    /**
     * @notice Expand the reward range 
     * @param lowerBound_ New lower bound of the reward range
     * @param upperBound_ New upper bound of the reward range
     */
    function expandRewardRange(
        uint256 lowerBound_,
        uint256 upperBound_
    ) external onlyOwner {
        // reward range must be greater than or equal to the current range
        require(upperBound_ >= upperBound && lowerBound_ <= lowerBound, "proposed range is invalid");

        require(upperBound_ > lowerBound_);
        require(upperBound_ > 0 && upperBound_ < 7388);
        require(lowerBound_ > 0 && lowerBound_ < 7388);

        upperBound = upperBound_;
        lowerBound = lowerBound_;

        emit RangeExpanded(lowerBound, upperBound);
    }

    /**************************/
    /** Restricted Functions **/
    /**************************/

    /**
     * @notice Notify reward amount for a specific reward token
     * @param rewardsToken_ Address of the reward token
     * @param reward_ Amount of reward to be given
    */
    function notifyRewardAmount(
        address rewardsToken_,
        uint256 reward_
    ) external updateReward(0) {
        require(rewardData[rewardsToken_].rewardsDistributor == msg.sender);
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(rewardsToken_).safeTransferFrom(
            msg.sender,
            address(this),
            reward_
        );

        if (block.timestamp >= rewardData[rewardsToken_].periodFinish) {
            rewardData[rewardsToken_].rewardRate = reward_.div(
                rewardData[rewardsToken_].rewardsDuration
            );
        } else {
            uint256 remaining = rewardData[rewardsToken_].periodFinish.sub(
                block.timestamp
            );
            uint256 leftover = remaining.mul(
                rewardData[rewardsToken_].rewardRate
            );
            rewardData[rewardsToken_].rewardRate = reward_.add(leftover).div(
                rewardData[rewardsToken_].rewardsDuration
            );
        }

        rewardData[rewardsToken_].lastUpdateTime = block.timestamp;
        rewardData[rewardsToken_].periodFinish   = block.timestamp.add(
            rewardData[rewardsToken_].rewardsDuration
        );
        emit RewardAdded(reward_);
    }

    /**
     * @notice Recover ERC20 tokens sent to this contract by mistake
     * @param tokenAddress_ Address of the token to recover
     * @param tokenAmount_ Amount of tokens to recover
    */
    function recoverERC20(
        address tokenAddress_,
        uint256 tokenAmount_
    ) external onlyOwner {
        require(
            rewardData[tokenAddress_].lastUpdateTime == 0,
            "Cannot withdraw reward token"
        );
        IERC20(tokenAddress_).safeTransfer(owner(), tokenAmount_);
        emit Recovered(tokenAddress_, tokenAmount_);
    }

    function setRewardsDuration(
        address rewardsToken_,
        uint256 rewardsDuration_
    ) external {
        require(
            block.timestamp > rewardData[rewardsToken_].periodFinish,
            "Reward period still active"
        );
        require(rewardData[rewardsToken_].rewardsDistributor == msg.sender);
        require(rewardsDuration_ > 0, "Reward duration must be non-zero");
        rewardData[rewardsToken_].rewardsDuration = rewardsDuration_;
        emit RewardsDurationUpdated(
            rewardsToken_,
            rewardData[rewardsToken_].rewardsDuration
        );
    }

    /**
     * @notice Set rewards distributor for a specific reward token 
     * @param rewardsToken_ Address of the reward token
     * @param rewardsDistributor_ Address of the new rewards distributor
    */
    function setRewardsDistributor(
        address rewardsToken_,
        address rewardsDistributor_
    ) external onlyOwner {
        rewardData[rewardsToken_].rewardsDistributor = rewardsDistributor_;
    }

    /**************************/
    /** External Functions **/
    /**************************/

    /**
     *  @dev    === Revert on ===
     *  @dev    not owner `NotOwnerOfDeposit()`
     *  @dev    === Emit events ===
     *  @dev    - `Stake`
     */
    function stake(
        uint256 tokenId_
    ) external override nonReentrant whenNotPaused updateReward(tokenId_) {

        // check that tokenId is a valid LP NFT
        require(address(ajnaPool) == positionManager.poolKey(tokenId_));

        // check that msg.sender is owner of tokenId
        require(IERC721(address(positionManager)).ownerOf(tokenId_) == msg.sender);

        StakeInfo storage stakeInfo = _stakes[tokenId_];
        stakeInfo.owner = msg.sender;

        // initialize last time interaction at staking epoch
        stakeInfo.lastUpdated = block.timestamp;

        uint256[] memory positionIndexes = positionManager.getPositionIndexes(tokenId_);
        uint256 noOfPositions            = positionIndexes.length;
        uint256 bucketId;

        for (uint256 i = 0; i < noOfPositions; ) {
            bucketId = positionIndexes[i];
            // only allow positions in reward range
            require(bucketId <= upperBound && bucketId >= lowerBound, "Position not in range");
 
            uint256 lps     = positionManager.getLP(tokenId_, bucketId);
            uint256 qtValue = poolUtils.lpToQuoteTokens(address(ajnaPool), lps, bucketId);
            uint256 price   = poolUtils.indexToPrice(bucketId);

            // price^2 * lps
            uint256 priceWeightedLPs = Maths.wmul(
                                            Maths.wmul(price, price),
                                            qtValue
                                        ).div(1e18);

            totalSupply  = totalSupply.add(priceWeightedLPs);
            stakeInfo.lps = stakeInfo.lps.add(priceWeightedLPs);
 
            unchecked { ++i; } // bounded by array length
        }

        emit Stake(msg.sender, address(ajnaPool), tokenId_);

        // transfer LP NFT to this contract
        IERC721(address(positionManager)).transferFrom(msg.sender, address(this), tokenId_);
    }

    function unstake(
        uint256 tokenId_
    ) public override nonReentrant updateReward(tokenId_) {
        StakeInfo storage stakeInfo = _stakes[tokenId_];

        if (msg.sender != stakeInfo.owner) revert NotOwnerOfDeposit();

        // subtract lp from reward range
        totalSupply -= stakeInfo.lps;

        // remove recorded stake info
        delete _stakes[tokenId_];

        emit Unstake(msg.sender, address(ajnaPool), tokenId_);

        // transfer LP NFT from contract to sender
        IERC721(address(positionManager)).transferFrom(address(this), msg.sender, tokenId_);
    }

    function getReward(
        uint256 tokenId_
    ) public nonReentrant updateReward(tokenId_) {

        StakeInfo storage stakeInfo = _stakes[tokenId_];
        if (msg.sender != stakeInfo.owner) revert NotOwnerOfDeposit();

        for (uint256 i = 0; i < rewardTokens.length; ) {
            address rewardsToken = rewardTokens[i];
            uint256 reward       = stakeInfo.rewards[rewardsToken].owed;

            if (reward > 0) {
                stakeInfo.rewards[rewardsToken].owed = 0;
                IERC20(rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, rewardsToken, reward);
            }
            unchecked { ++i; } // bounded by array length
        }
    }

    /**
     * @notice Exit staking and claim rewards
     * @param tokenId_ ID of the LP token
    */
    function exit(
        uint256 tokenId_
    ) external {
        getReward(tokenId_);
        unstake(tokenId_);
    }

    function getStakeInfo(
        uint256 tokenId_
    ) external view returns (address, uint256, uint256) {
        return (
            _stakes[tokenId_].owner,
            _stakes[tokenId_].lastUpdated,
            _stakes[tokenId_].lps
        );
    }

    /**
     * @notice Calculate earned rewards for a LP token and reward token
     * @param tokenId_ ID of the staked LP token  
     * @param rewardsToken_ Address of the reward token
     * @return earned rewards amount
    */ 
    function earned(
        uint256 tokenId_,
        address rewardsToken_
    ) public view returns (uint256) {

        StakeInfo storage stakeInfo = _stakes[tokenId_];
        uint256 rewardPerToken_ = rewardPerToken(rewardsToken_);

        return stakeInfo.lps
            .mul(
                rewardPerToken_.sub(
                    stakeInfo.rewards[rewardsToken_].userRewardPerTokenStoredPaid
                )
            )
            .div(1e18)
            .add(stakeInfo.rewards[rewardsToken_].owed);
    }

    /**
     * @notice Get the reward per staked token
     * @param rewardsToken_ Address of the reward token
     * @return Reward per staked token
    */
    function rewardPerToken(
        address rewardsToken_
    ) public view returns (uint256) {

        if (totalSupply == 0) {
            return rewardData[rewardsToken_].rewardPerTokenStored;
        }

        return rewardData[rewardsToken_].rewardPerTokenStored.add(
                lastTimeRewardApplicable(rewardsToken_)
                    .sub(rewardData[rewardsToken_].lastUpdateTime)
                    .mul(rewardData[rewardsToken_].rewardRate)
                    .mul(1e18)
                    .div(totalSupply)
            );
    }

    /**
     * @notice Get the last time reward is applicable
     * @param rewardsToken_ Address of the reward token 
     * @return Last time reward is applicable
    */
    function lastTimeRewardApplicable(
        address rewardsToken_
    ) public view returns (uint256) {
        return
            Math.min(block.timestamp, rewardData[rewardsToken_].periodFinish);
    }

    function getRewardForDuration(
        address rewardsToken_
    ) external view returns (uint256) {
        return
            rewardData[rewardsToken_].rewardRate.mul(
                rewardData[rewardsToken_].rewardsDuration
            );
    }

    /**
     * @notice Get stake rewards info for a token ID and reward token
     * @param tokenId_ ID of the staked LP token
     * @param rewardsToken_ Address of the reward token
     * @return owed rewards amount, userRewardPerTokenStoredPaid  
    */
    function getStakeRewardsInfo(
        uint256 tokenId_,
        address rewardsToken_
    ) external view returns (uint256, uint256) {
        return (
            _stakes[tokenId_].rewards[rewardsToken_].owed,
            _stakes[tokenId_].rewards[rewardsToken_].userRewardPerTokenStoredPaid
        );
    }

    /**************************/
    /*** Modifier Functions ***/
    /**************************/

    modifier updateReward(uint256 tokenId_) {
        StakeInfo storage stakeInfo = _stakes[tokenId_];

        for (uint256 i; i < rewardTokens.length; ) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime       = lastTimeRewardApplicable(token);

            if (tokenId_ != 0) {
                stakeInfo.rewards[token].owed = earned(tokenId_, token);
                stakeInfo.rewards[token].userRewardPerTokenStoredPaid = rewardData[token].rewardPerTokenStored;
            }

            unchecked { ++i; } // bounded by array length
        }
        _;
    }
}