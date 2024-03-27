## multi-reward-range
The MultiRewardRange is a staking contract designed for pool lenders in the Ajna protocol. It allows lenders to stake their position NFTs, which represent their shares in the lending pool, and earn multiple ERC20 reward tokens based on their staked positions. The contract defines a reward range, specified by a lower and upper bound, which determines the eligible positions for staking. Lenders can stake, unstake, and claim their earned rewards for each reward token, while the contract keeps track of the total staked supply, reward rates, and reward durations. The contract also includes various safety measures and access control mechanisms to ensure secure and fair distribution of rewards to the stakers.

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
