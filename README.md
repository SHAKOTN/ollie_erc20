# OllieCoin

## How it works

The token tracks holder balances using checkpoints - basically snapshots of balances whenever they change. When someone transfers tokens, we record their new balance in a checkpoint. Then, when distributing rewards, each holder can claim based on what they held during each distribution period.

The tricky part was making the distribution function O(1) - it doesn't loop through holders or anything. Instead, it just records that a distribution happened and what reward token was used. Users can claim their rewards later.

**NOTE**: Specification said to distribute reward tokens to holders in 1:1 ratio with OllieCoin. I found this future prone to abuse, so I made claim weighed by the amount of OllieCoin held by the user at the time of distribution. 


### Key features
- Regular ERC20 stuff (transfers, balances, etc)
- Can distribute any ERC20 token as rewards
- Users claim rewards for all unclaimed periods at once
- No double-claiming (each period can only be claimed once per user)
- Gas efficient (uses binary search to find historical balances)

## Technical details

The contract uses a checkpoint system instead of copying balances for every period. It only stores balance changes, then uses binary search to find what someone held at a specific time. Pretty neat way to save gas.

When distributing rewards:
1. Owner sends reward tokens to contract 
2. Period counter increments
3. Much O(1)

When claiming:
1. Contract figures out which periods you haven't claimed yet
2. Looks up your balance for each period using checkpoints
3. Sends you the rewards you're owed


## Testing
Run `forge test`

## Cross Chain Architecture
Ok, so for cross chain architecture it can get way too complex if we want to build a super-UX.
If we want to make it that users can hold tokens on chain A and then claim rewards on chain B, we will have to send lots of LZ messages.
We will also need to track totalSupply of OllieCoin in order to distribute rewards in weighted manner.

Hence, for starters, I suggest a very simple architecture: just deploy OllieCoin OFT on each chain and distribute rewards on each chain. This way, users can claim rewards on the chain they hold OllieCoin on
and we won't need to send any messages between chains.
Notes:
- Each chain operates independently
- Users bridge OllieCoin using OFT
- Rewards distributed locally per chain
- Claims processed on holding chain

```
+----------------+     OFT bridge      +----------------+
|   Chain A      | <----------------> |   Chain B      |
|  +----------+  |                    |  +----------+  |
|  |OllieCoin |  |                    |  |OllieCoin |  |
|  |  (OFT)   |  |                    |  |  (OFT)   |  |
|  +----------+  |                    |  +----------+  |
|  +----------+  |                    |  +----------+  |
|  |RewardCoin|  |                    |  |RewardCoin|  |
|  +----------+  |                    |  +----------+  |
|                |                    |                |
| Local Rewards  |                    | Local Rewards  |
| Distribution   |                    | Distribution   |
| & Claims      |                    | & Claims      |
+----------------+                    +----------------+
        ^                                    ^
        |          +----------------+        |
        |          |   Chain C      |        |
        |          |  +----------+  |        |
        |          |  |OllieCoin |  |        |
        |          |  |  (OFT)   |  |        |
        |          |  +----------+  |        |
        |          |  +----------+  |        |
        |          |  |RewardCoin|  |        |
        |          |  +----------+  |        |
        |          |                |        |
        |          | Local Rewards  |        |
        |          | Distribution   |        |
        |          |  & Claims      |        |
        |          +----------------+        |
        |                                    |
        +------------------------------------+
              OFT bridge connections

```
We can ideate on this and discuss this further.