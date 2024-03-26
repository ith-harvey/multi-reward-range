// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import '@ajna-core/PoolInfoUtils.sol';
import 'src/MultiRewardRange.sol';

import { IERC20Pool } from '@ajna-core/interfaces/pool/erc20/IERC20Pool.sol';
import { MultiRewardRangeTestHelperContract } from './MultiRewardRangeUtils.sol';
import { IMultiRewardRangeEvents } from 'src/interfaces/IMultiRewardRangeEvents.sol';

import '@std/console2.sol';

contract MultiRewardRangeTest is IMultiRewardRangeEvents, MultiRewardRangeTestHelperContract {

    address internal _borrower;
    address internal _borrower2;
    address internal _borrower3;
    address internal _lender;
    address internal _lender1;

    address internal _shitToken;
    
    uint256 constant BLOCKS_IN_DAY = 7200;
    mapping (uint256 => address) internal tokenIdToMinter;
    mapping (address => uint256) internal minterToBalance;

    uint256 internal _p9_91     = 9.917184843435912074 * 1e18;
    uint256 internal _p9_81     = 9.818751856078723036 * 1e18;
    uint256 internal _p9_72     = 9.721295865031779605 * 1e18;
    uint256 internal _p9_62     = 9.624807173121239337 * 1e18;
    uint256 internal _p9_52     = 9.529276179422528643 * 1e18;

    uint16 internal _i9_91     = 3696;
    uint16 internal _i9_81     = 3698;
    uint16 internal _i9_72     = 3700;
    uint16 internal _i9_62     = 3702;
    uint16 internal _i9_52     = 3704;

    function setUp() external {
        vm.startPrank(address(this));

        // instantiate test minters
        _minterOne   = makeAddr("minterOne");
        _minterTwo   = makeAddr("minterTwo");

        _mintQuoteAndApproveTokens(_minterOne,  500_000_000 * 1e18);
        _mintQuoteAndApproveTokens(_minterTwo,  500_000_000 * 1e18);

        vm.startPrank(_owner);
        _rewardsManager = new MultiRewardRange(_owner, _pool, _positionManager,_i9_91, _i9_52);
        vm.stopPrank();
    }

    function testStakeToken() external {

        // configure NFT position one
        uint256[] memory depositIndexes = new uint256[](3);
        depositIndexes[0] = _i9_52;
        depositIndexes[1] = _i9_62;
        depositIndexes[2] = _i9_72;

        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // minterOne deposits their NFT into the rewards contract
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });
    }

    function testUnstakeToken() external {

        // configure NFT position one
        uint256[] memory depositIndexes = new uint256[](4);
        depositIndexes[0] = _i9_52;
        depositIndexes[1] = _i9_62;
        depositIndexes[2] = _i9_72;
        depositIndexes[3] = _i9_81;

        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // minterOne deposits their NFT into the rewards contract
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        _unstakeToken({
            pool:              address(_pool),
            owner:             _minterOne,
            tokenId:           tokenIdOne
        });
    }

    function testExitToken() external {

        // configure NFT position one
        uint256[] memory depositIndexes = new uint256[](4);
        depositIndexes[0] = _i9_52;
        depositIndexes[1] = _i9_62;
        depositIndexes[2] = _i9_72;
        depositIndexes[3] = _i9_81;

        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // should revert if not an Ajna pool
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        skip(10 days);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 9.999999999999935999 * 1e18;

        // claim rewards accrued since deposit
        _exit({
            pool:           address(_pool),
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
    }


    function testExitMultipleStakers() external {

        // distribute rewards
        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // set deposit indexes
        uint256[] memory depositIndexes = new uint256[](1);
        uint256[] memory depositIndexes2 = new uint256[](1);
        depositIndexes[0] = _i9_52;
        depositIndexes2[0] = _i9_62;

        // stake NFT position one
        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 2_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        // stake NFT position two
        uint256 tokenIdTwo = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes2,
            minter:     _minterTwo,
            mintAmount: 2_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterTwo,
            tokenId: tokenIdTwo
        });

        skip(10 days);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 5.049881429389124602 * 1e18;

        // minterTwo claims a bit more rewards than minterOne due to price difference
        _exit({
            pool:           address(_pool),
            from:           _minterTwo,
            tokenId:        tokenIdTwo,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });

        rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 4.950118570610811397 * 1e18;

        // claim rewards accrued since deposit
        _exit({
            pool:           address(_pool),
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
    }

    function testGetrewardsMultipleStakersRewardDiffOneLazy() external {

        // distribute rewards
        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // set deposit indexes
        uint256[] memory depositIndexes = new uint256[](1);
        uint256[] memory depositIndexes2 = new uint256[](1);
        depositIndexes[0] = _i9_52;
        depositIndexes2[0] = _i9_81;

        // stake NFT position one
        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 2_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        // stake NFT position two
        uint256 tokenIdTwo = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes2,
            minter:     _minterTwo,
            mintAmount: 2_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterTwo,
            tokenId: tokenIdTwo
        });


        skip (100 days);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 48.504183904852912368 * 1e18;

        // claim rewards accrued since deposit
        _getRewards({
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });

        skip(100 days);

        rewardAmounts[0] = 48.504183904852912368 * 1e18;

        // claim rewards
        _getRewards({
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });

        rewardAmounts[0] = 102.991632190292895263 * 1e18;

        // Claim rewards
        _exit({
            pool:           address(_pool),
            from:           _minterTwo,
            tokenId:        tokenIdTwo,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
    }

    function testExpandingRewards() external {
        // distribute rewards
        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        uint256[] memory depositIndexes = new uint256[](1);
        depositIndexes[0] = _i9_52;

        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        // expand reward range
        assertEq(_priceAt(3680), 10.741016805797265743 * 1e18);
        assertEq(_priceAt(3710), 9.248334802095192832 * 1e18);

        skip(100 days);

        changePrank(_owner);
        _rewardsManager.expandRewardRange(3680, 3710);

        uint256[] memory depositIndexes2 = new uint256[](1);
        depositIndexes2[0] = 3680;

        uint256 tokenIdTwo = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes2,
            minter:     _minterTwo,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterTwo,
            tokenId: tokenIdTwo
        });

        skip(10 days);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 104.404314969489936470 * 1e18;

        _exit({
            pool:           address(_pool),
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });

        rewardAmounts[0] = 5.595685030509359529 * 1e18;

        _exit({
            pool:           address(_pool),
            from:           _minterTwo,
            tokenId:        tokenIdTwo,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
    }

    function testExitTokenAboveMPValueExtractorNoRewards() external {

        // configure NFT position one
        uint256[] memory depositIndexes = new uint256[](4);
        depositIndexes[0] = _i9_52;
        depositIndexes[1] = _i9_62;
        depositIndexes[2] = _i9_72;
        depositIndexes[3] = _i9_81;

        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // should revert if not an Ajna pool
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        skip(10 days);

        // configure collateral only position
        uint256[] memory depositIndexes2 = new uint256[](1);
        depositIndexes2[0] = _i9_91;

        changePrank(_minterTwo);
        deal(address(_collateral), _minterTwo, 1_000.0 * 1e18);
        _collateral.approve(address(_pool), type(uint256).max);
        uint256 tokenId_ = _positionManager.mint(address(_pool), _minterTwo, keccak256("ERC20_NON_SUBSET_HASH"));

        uint256[] memory lpBal = new uint256[](1);
        lpBal[0] = IERC20Pool(address(_pool)).addCollateral(1_000.0 * 1e18, _i9_91, type(uint256).max);
        assertEq(lpBal[0], 9_917.184843435912074000 * 1e18);

        _pool.increaseLPAllowance(address(_positionManager), depositIndexes2, lpBal);
        _positionManager.memorializePositions(address(_pool), tokenId_, depositIndexes2);

        // the collateral only staker does not receive rewards since there is no deposit in the bucket, on stake.
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterTwo,
            tokenId: tokenId_
        });

        skip(10 days);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 19.999999999999871999 * 1e18;

        // claim rewards accrued since deposit
        _exit({
            pool:           address(_pool),
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
        
        // proof of no rewards earned
        assertEq(_rewardsManager.earned(tokenId_, address(_shitTokenOne)), 0);
        rewardAmounts[0] = 0;

        // claim rewards accrued since deposit
        _exit({
            pool:           address(_pool),
            from:           _minterTwo,
            tokenId:        tokenId_,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
    }

    function testExitBelowMPValueExtractorRewards() external {

        assertEq(_priceAt(4000), 2.177236638543800931 * 1e18);

        vm.startPrank(_owner);
        _rewardsManager = new MultiRewardRange(_owner, _pool, _positionManager,_i9_91, 4_000);
        vm.stopPrank();

        uint256[] memory depositIndexes = new uint256[](1);
        depositIndexes[0] = 4000;

        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // should revert if not an Ajna pool
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        skip(10 days);

        // proof of rewards earned freeriding
        assertEq(_rewardsManager.earned(tokenIdOne, address(_shitTokenOne)), 9.999999999999935999 * 1e18);

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 9.999999999999935999 * 1e18;

        _getRewards({
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });

        assertEq(_rewardsManager.earned(tokenIdOne, address(_shitTokenOne)), 0);

        uint256[] memory depositIndexes2 = new uint256[](1);
        depositIndexes2[0] = _i9_91;

        uint256 tokenIdTwo = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes2,
            minter:     _minterTwo,
            mintAmount: 1_000 * 1e18,
            pool:       address(_pool)
        });

        // should revert if not an Ajna pool
        _stakeToken({
            pool:    address(_pool),
            owner:   _minterTwo,
            tokenId: tokenIdTwo
        });

        skip(10 days);

        // proof of diminishing rewards if counter balanced by higher priced stakers
        assertEq(_rewardsManager.earned(tokenIdOne, address(_shitTokenOne)), 0.459810255514809931 * 1e18);
        assertEq(_rewardsManager.earned(tokenIdTwo, address(_shitTokenOne)), 9.540189744485126068 * 1e18);
    }

    function testRecoverERC20() external {
        deal(address(_shitTokenOne), address(_rewardsManager), 500 * 1e18);

        assertEq(_shitTokenOne.balanceOf(address(_rewardsManager)), 500 * 1e18);
        assertEq(_shitTokenOne.balanceOf(_owner),                    0);

        changePrank(_owner);
        _rewardsManager.recoverERC20(address(_shitTokenOne), 250 * 1e18);

        assertEq(_shitTokenOne.balanceOf(address(_rewardsManager)), 250 * 1e18);
        assertEq(_shitTokenOne.balanceOf(_owner),                    250 * 1e18);
    }

    function testRewardsDuration() external {
        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        changePrank(_owner);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        skip(200 days);

        uint256 reward = _rewardsManager.getRewardForDuration(address(_shitTokenOne));
        assertEq(reward, 499.999999999996800000 * 1e18);
        
        vm.expectRevert();
        _rewardsManager.setRewardsDuration(address(_shitTokenOne), 1000 days); 

        // reward duration cant change unless existing reward duration is over
        reward = _rewardsManager.getRewardForDuration(address(_shitTokenOne));
        assertEq(reward, 499.999999999996800000 * 1e18);

        skip(310 days);
        _rewardsManager.setRewardsDuration(address(_shitTokenOne), 1000 days);

        reward = _rewardsManager.getRewardForDuration(address(_shitTokenOne));
        assertEq(reward, 999.999999999993600000 * 1e18);
    }

    function testSingleActorMultipleNFTs() external {
        // distribute rewards
        deal(address(_shitTokenOne), _owner, 500 * 1e18);
        _distributeRewards({
            owner:           _owner,
            distributor:     _owner,
            rewardsToken:    address(_shitTokenOne),
            rewardsAmount:   500 * 1e18,
            rewardsDuration: 500 days 
        });

        // set deposit indexes
        uint256[] memory depositIndexes = new uint256[](1);
        uint256[] memory depositIndexes2 = new uint256[](1);
        depositIndexes[0] = _i9_52;
        depositIndexes2[0] = _i9_62;

        // stake NFT position one
        uint256 tokenIdOne = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes,
            minter:     _minterOne,
            mintAmount: 2_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdOne
        });

        skip(10 days);

        assertEq(_rewardsManager.earned(tokenIdOne, address(_shitTokenOne)), 9.999999999999935999 * 1e18);

        // stake NFT position two
        uint256 tokenIdTwo = _mintAndMemorializePositionNFT({
            indexes:    depositIndexes2,
            minter:     _minterOne,
            mintAmount: 2_000 * 1e18,
            pool:       address(_pool)
        });

        _stakeToken({
            pool:    address(_pool),
            owner:   _minterOne,
            tokenId: tokenIdTwo
        });

        skip(10 days);
        
        // claim rewards accrued since deposit

        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(_shitTokenOne);

        uint256[] memory rewardAmounts = new uint256[](1);
        rewardAmounts[0] = 14.950118570610747397 * 1e18;

        _exit({
            pool:           address(_pool),
            from:           _minterOne,
            tokenId:        tokenIdOne,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });

        rewardAmounts[0] = 5.049881429389124602 * 1e18;

        // claim rewards accrued since deposit
        _exit({
            pool:           address(_pool),
            from:           _minterOne,
            tokenId:        tokenIdTwo,
            rewardTokens:   rewardTokens,
            rewardAmounts:  rewardAmounts
        });
    }
}