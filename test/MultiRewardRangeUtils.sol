// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import '@std/Test.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';

import {
    MAX_FENWICK_INDEX,
    COLLATERALIZATION_FACTOR,
    _borrowFeeRate
} from '@ajna-core/libraries/helpers/PoolHelper.sol';

import { IMultiRewardRange }       from 'src/interfaces/IMultiRewardRange.sol';
import { IMultiRewardRangeEvents } from 'src/interfaces/IMultiRewardRangeEvents.sol';

import { Maths }             from '@ajna-core/libraries/internal/Maths.sol';
import { Token }             from '@ajna-core-test/utils/Tokens.sol';
import { ERC20Pool }         from '@ajna-core/ERC20Pool.sol';
import { ERC20PoolFactory }  from '@ajna-core/ERC20PoolFactory.sol';
import { ERC721PoolFactory } from '@ajna-core/ERC721PoolFactory.sol';
import { PositionManager }   from '@ajna-core/PositionManager.sol';
import { PoolInfoUtils }     from '@ajna-core/PoolInfoUtils.sol';

import { IPool }            from '@ajna-core/interfaces/pool/IPool.sol';
import { IPoolErrors }      from '@ajna-core/interfaces/pool/commons/IPoolErrors.sol';
import { IPositionManager } from '@ajna-core/interfaces/position/IPositionManager.sol';


abstract contract MultiRewardRangeTestUtils is IMultiRewardRangeEvents, Test {

    IPool             internal _pool;
    PoolInfoUtils     internal _poolUtils;

    Token internal _collateral;
    Token internal _quote;

    ERC20PoolFactory internal _poolFactory;

    address internal _minterOne;
    address internal _minterTwo;
    address internal _minterThree;
    address internal _minterFour;
    address internal _minterFive;

    // mainnet address of AJNA token, because tests are forked
    address internal _ajna = 0x9a96ec9B57Fb64FbC60B423d1f4da7691Bd35079;

    // ERC20 internal _ajnaToken;

    IPool            internal _poolTwo;
    IMultiRewardRange internal _rewardsManager;
    IPositionManager internal _positionManager;

    uint256 internal REWARDS_CAP = 0.8 * 1e18;

    struct TriggerReserveAuctionParams {
        address borrower;
        uint256 borrowAmount;
        uint256 limitIndex;
        IPool pool;
    }

    constructor() {
        // vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        _collateral  = new Token("Collateral", "C");
        _quote       = new Token("Quote", "Q");
        _poolFactory = new ERC20PoolFactory(_ajna);
        _pool        = ERC20Pool(_poolFactory.deployPool(address(_collateral), address(_quote), 0.05 * 10**18));
        _poolUtils   = new PoolInfoUtils();
    }


    function _stakeToken(address pool, address owner, uint256 tokenId) internal {
        changePrank(owner);

        // approve and deposit NFT into rewards contract
        PositionManager(address(_positionManager)).approve(address(_rewardsManager), tokenId);
        vm.expectEmit(true, true, true, true);
        emit Stake(owner, address(pool), tokenId);
        _rewardsManager.stake(tokenId);

        // check token was transferred to rewards contract
        (address ownerInf,, ) = _rewardsManager.getStakeInfo(tokenId);
        assertEq(PositionManager(address(_positionManager)).ownerOf(tokenId), address(_rewardsManager));
        assertEq(ownerInf, owner);
    }

    function _unstakeToken(
        address owner,
        address pool,
        uint256 tokenId
    ) internal {
        // token owner is Rewards manager
        assertEq(ERC721(address(_positionManager)).ownerOf(tokenId), address(_rewardsManager));

        // when the token is unstaked in emergency mode then no claim event is emitted
        vm.expectEmit(true, true, true, true);
        emit Unstake(owner, address(pool), tokenId);
        _rewardsManager.unstake(tokenId);

        // token owner is staker
        assertEq(ERC721(address(_positionManager)).ownerOf(tokenId), owner);
    }

    function _getRewards(
        address from,
        uint256 tokenId,
        address[] memory rewardTokens,
        uint256[] memory rewardAmounts
    ) internal {
        // token owner is Rewards manager
        assertEq(ERC721(address(_positionManager)).ownerOf(tokenId), address(_rewardsManager));

        changePrank(from);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardAmounts[i] > 0) {
                vm.expectEmit(true, true, true, true);
                emit RewardPaid(from, rewardTokens[i], rewardAmounts[i]);
            }
        }
        _rewardsManager.getReward(tokenId);

        // token owner is still Rewards manager
        assertEq(ERC721(address(_positionManager)).ownerOf(tokenId), address(_rewardsManager));
    }

    function _exit(
        address from,
        address pool,
        uint256 tokenId,
        address[] memory rewardTokens,
        uint256[] memory rewardAmounts
    ) internal {
        // token owner is Rewards manager
        assertEq(ERC721(address(_positionManager)).ownerOf(tokenId), address(_rewardsManager));

        changePrank(from);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardAmounts[i] > 0) {
                vm.expectEmit(true, true, true, true);
                emit RewardPaid(from, rewardTokens[i], rewardAmounts[i]);
            }
        }
        emit Unstake(from, address(pool), tokenId);
        _rewardsManager.exit(tokenId);

        // token owner is staker
        assertEq(ERC721(address(_positionManager)).ownerOf(tokenId), from);
    }
}

abstract contract MultiRewardRangeTestHelperContract is MultiRewardRangeTestUtils {

    address         internal _owner;
    address         internal _bidder;
    address         internal _updater;
    address         internal _updater2;

    Token internal _collateralOne;
    Token internal _quoteOne;
    Token internal _collateralTwo;
    Token internal _quoteTwo;


    Token internal _shitTokenOne;
    Token internal _shitTokenTwo;


    constructor() {

        vm.makePersistent(_ajna);

        _owner  = makeAddr("owner");

        _positionManager = new PositionManager(_poolFactory, new ERC721PoolFactory(_ajna));

        _collateralOne = new Token("Collateral 1", "C1");
        _quoteOne      = new Token("Quote 1", "Q1");
        _collateralTwo = new Token("Collateral 2", "C2");
        _quoteTwo      = new Token("Quote 2", "Q2");

        _shitTokenOne  = new Token("Shit 1", "S1");
        _shitTokenTwo  = new Token("Shit 2", "S2");

        _poolTwo       = ERC20Pool(_poolFactory.deployPool(address(_collateralTwo), address(_quoteTwo), 0.05 * 10**18));

    }

    function _mintQuoteAndApproveTokens(address operator_, uint256 mintAmount_) internal {
        deal(address(_quote), operator_, mintAmount_);

        changePrank(operator_);
        _quote.approve(address(_pool), type(uint256).max);
        _collateral.approve(address(_pool), type(uint256).max);
    }

    function _mintCollateralAndApproveTokens(address operator_, uint256 mintAmount_) internal {
        deal(address(_collateral), operator_, mintAmount_);

        changePrank(operator_);
        _collateral.approve(address(_pool), type(uint256).max);
        _quote.approve(address(_pool), type(uint256).max);
    }

    // calculate required collateral to borrow a given amount at a given limitIndex
    function _requiredCollateral(uint256 borrowAmount, uint256 indexPrice) internal view returns (uint256 requiredCollateral_) {
        // calculate the required collateral based upon the borrow amount and index price
        (uint256 interestRate, ) = _pool.interestRateInfo();
        uint256 newInterestRate = Maths.wmul(interestRate, 1.1 * 10**18); // interest rate multipled by increase coefficient
        uint256 expectedDebt = Maths.wmul(borrowAmount, _borrowFeeRate(newInterestRate) + Maths.WAD);
        requiredCollateral_ = Maths.wdiv(Maths.wmul(expectedDebt, COLLATERALIZATION_FACTOR), _poolUtils.indexToPrice(indexPrice));
    }

    function _distributeRewards(
        address owner,
        address distributor,
        address rewardsToken,
        uint256 rewardsAmount,
        uint256 rewardsDuration
    ) internal {
        changePrank(owner);
        _rewardsManager.addReward(rewardsToken, distributor, rewardsDuration);

        changePrank(distributor);
        ERC20(rewardsToken).approve(address(_rewardsManager), rewardsAmount);
        _rewardsManager.notifyRewardAmount(rewardsToken, rewardsAmount);

    }

    function _mintAndMemorializePositionNFT(
        address minter,
        uint256 mintAmount,
        address pool,
        uint256[] memory indexes
    ) internal returns (uint256 tokenId_) {
        changePrank(minter);

        Token collateral = Token(ERC20Pool(address(pool)).collateralAddress());
        Token quote = Token(ERC20Pool(address(pool)).quoteTokenAddress());

        // deal tokens to the minter
        deal(address(quote), minter, mintAmount * indexes.length);

        // approve tokens
        collateral.approve(address(pool), type(uint256).max);
        quote.approve(address(pool), type(uint256).max);

        tokenId_ = _positionManager.mint(address(pool), minter, keccak256("ERC20_NON_SUBSET_HASH"));

        uint256[] memory lpBalances = new uint256[](indexes.length);

        for (uint256 i = 0; i < indexes.length; i++) {
            ERC20Pool(address(pool)).addQuoteToken(mintAmount, indexes[i], type(uint256).max);
            (lpBalances[i], ) = ERC20Pool(address(pool)).lenderInfo(indexes[i], minter);
        }

        ERC20Pool(address(pool)).increaseLPAllowance(address(_positionManager), indexes, lpBalances);

        _positionManager.memorializePositions(pool, tokenId_, indexes);
    }

    function _earnPoolInterest(
        address borrower,
        address pool,
        uint256 borrowAmount,
        uint256 timeToPass,
        uint256 limitIndex
    ) internal {

        // fund borrower to write state required for reserve auctions
        changePrank(borrower);
        Token collateral = Token(ERC20Pool(address(pool)).collateralAddress());
        Token quote = Token(ERC20Pool(address(pool)).quoteTokenAddress());
        deal(address(quote), borrower, borrowAmount);

        // approve tokens
        collateral.approve(address(pool), type(uint256).max);
        quote.approve(address(pool), type(uint256).max);

        uint256 collateralToPledge = _requiredCollateral(borrowAmount, limitIndex);
        deal(address(_collateral), borrower, collateralToPledge);

        // borrower drawsDebt from the pool
        ERC20Pool(address(pool)).drawDebt(borrower, borrowAmount, limitIndex, collateralToPledge);

        // allow time to pass for interest to accumulate
        skip(timeToPass);

        // borrower repays some of their debt, providing reserves to be claimed
        // don't pull any collateral, as such functionality is unrelated to reserve auctions
        ERC20Pool(address(pool)).repayDebt(borrower, borrowAmount, 0, borrower, MAX_FENWICK_INDEX);
    }

 
}