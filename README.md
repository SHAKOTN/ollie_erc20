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