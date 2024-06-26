## multi-reward-range
The MultiRewardRange is a staking contract designed for pool lenders in the Ajna protocol. It allows lenders to stake their position NFTs, which represent their shares in the lending pool, and earn multiple ERC20 reward tokens based on their staked positions. The contract defines a reward range, specified by a lower and upper bound, which determines the eligible positions for staking. Lenders can stake, unstake, and claim their earned rewards for each reward token, while the contract keeps track of the total staked supply, reward rates, and reward durations. The contract also includes various safety measures and access control mechanisms to ensure secure and fair distribution of rewards to the stakers.

## How it Works

The `MultiRewardRange` contract allows users to stake their Ajna Position NFTs and earn multiple reward tokens based on their staked positions within a specified reward range. The contract defines a reward range using a lower and upper bound, which determines the eligible positions for staking.
*   The contract owner deploys the `MultiRewardRange` contract with the Ajna Pool address, PositionManager address, and the initial lower and upper bounds for the reward range.
*   The contract owner calls the `addReward` function to add reward tokens to the contract, specifying the reward token address, rewards distributor address, and the duration of the reward period (in seconds).
*   The rewards distributor for each reward token can notify the contract of the reward amount by calling `notifyRewardAmount`, which transfers the specified amount of reward tokens from their address to the contract and begins the reward cycle.
*   Users can stake their Ajna Position NFTs by calling the `stake` function, providing the token ID of their NFT. The contract checks if the NFT represents a position within the specified reward range and transfers the NFT from the user to the contract.
*   Staked positions accrue rewards based on the reward rates and durations set for each reward token. The rewards are calculated using a price-weighted formula that incentivizes staking at higher prices within the reward range.
*   Users can claim their earned rewards for each reward token by calling the `getReward` function, providing the token ID of their staked NFT.
*   Users can unstake their position NFT by calling the `unstake` function, which transfers the NFT back to the user and stops the accrual of rewards for that position.
*   The `exit` function allows users to claim their earned rewards and unstake their position NFT in a single transaction.
    

## Considerations

When using the `MultiRewardRange` contract, keep the following points in mind:
*   The contract owner can expand the reward range by calling the `expandRewardRange` function, providing new lower and upper bounds. The new range must be greater than or equal to the current range.
*   The rewards distributor for a specific reward token can update the reward duration by calling the `setRewardsDuration` function, but only when the current reward period for that token has ended.
*   The contract owner can change the rewards distributor for a specific reward token by calling the `setRewardsDistributor` function.
*   The contract automatically updates reward calculations whenever a user stakes, unstakes, claims rewards, or when the rewards distributor notifies the contract of a new reward amount.
*   The contract owner can recover any ERC20 tokens accidentally sent to the contract (except for the reward tokens) by calling the `recoverERC20` function.
*   Users must approve the `MultiRewardRange` contract to transfer their Ajna Position NFTs before staking.
*   The contract uses the `Pausable` functionality from OpenZeppelin, allowing the contract owner to pause and unpause the contract in case of emergencies or upgrades.
*   The `getRewardRange` function allows users to view the current reward range (lower and upper bounds) for the contract.
*   The reward range is susceptible to gaming if the lower and upper bounds are not set correctly. The contract owner should carefully consider the collateral and quote tokens volitility and external market price. If the reward range is set too high freeriders can stake with quote token and then earn rewards with only collateral in their position, not providing any value to the pool. Conversley, if the reward range is set too low, stakers may earn rewards at prices where their deposit is not utilized by borrowers. Worse come to worse the reward range can be expanded and or the distribution period may run out so another reward range contract can be deployed.

## Installation
```
git clone git@github.com:ith-harvey/multi-reward-range.git
cd multi-reward-range
```
```
git submodule update --init --recursive
```
```
forge clean && forge build
```
```
forge test
```

## Permissions
| User Type    | Accessible Methods                                                                                                                                                    |
|--------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Owner**        | - `addReward(address rewardsToken_, address rewardsDistributor_, uint256 rewardsDuration_)`: Add a new reward token to the contract.                                                            |
|              | - `expandRewardRange(uint16 lowerBound_, uint16 upperBound_)`: Expand the reward range by updating the lower and upper bounds.                                                                |
|              | - `recoverERC20(address tokenAddress_, uint256 tokenAmount_)`: Recover any ERC20 tokens accidentally sent to the contract, except for reward tokens.                                           |
|              | - `setRewardsDistributor(address rewardsToken_, address rewardsDistributor_)`: Set the rewards distributor address for a specific reward token.                                               |
| **Distributor**  | - `notifyRewardAmount(address rewardsToken_, uint256 reward_)`: Notify the contract of the reward amount for a specific reward token. The rewards distributor must have approved the contract to transfer the reward tokens. |
|              | - `setRewardsDuration(address rewardsToken_, uint256 rewardsDuration_)`: Set the rewards duration for a specific reward token. This can only be called by the rewards distributor when the reward period is not active. |
| **Everyone**     | - `stake(uint256 tokenId_)`: Stake an LP NFT and start earning rewards. The caller must be the owner of the NFT, and the NFT must represent a position within the specified reward range.         |
|              | - `unstake(uint256 tokenId_)`: Unstake a previously staked LP NFT and stop earning rewards. The caller must be the owner of the staked NFT.                                                    |
|              | - `getReward(uint256 tokenId_)`: Claim the earned rewards for a staked LP NFT. The caller must be the owner of the staked NFT.                                                                |
|              | - `exit(uint256 tokenId_)`: Claim the earned rewards and unstake a previously staked LP NFT in a single transaction. The caller must be the owner of the staked NFT.                        |
|              | - `totalSupply()`: View the total staked amount in the reward range.                                                                                                                           |
|              | - `getStakeInfo(uint256 tokenId_)`: View the staking information for a specific LP NFT.                                                                                                        |
|              | - `earned(uint256 tokenId_, address rewardsToken_)`: View the earned rewards for a specific LP NFT and reward token.                                                                          |
|              | - `getRewardForDuration(address rewardsToken_)`: View the reward amount for a specific reward token based on the current reward rate and duration.                                            |
|              | - `getStakeRewardsInfo(uint256 tokenId_, address rewardsToken_)`: View the staked rewards information for a specific LP NFT and reward token.                                                 |
|              | - `getRewardRange()`: View the current reward range (upper and lower bounds).                                                                                                                  |

Note: The `onlyOwner` modifier restricts certain methods to be called only by the contract owner, while the `updateReward` modifier is used internally to update reward calculations before executing the modified function.


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## credit where credit is due
Reused code from the SNX [MultiRewards.sol contract](https://github.com/curvefi/multi-rewards/blob/master/contracts/MultiRewards.sol)
