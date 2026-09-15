# Protocol Fee Module (`v1/protocol_fee/`)

Collects and distributes protocol fees from swaps, staking rewards, and withdrawals.

## Rules

- **Every fee transfer must call `AddToProtocolFee`** to register the amount. Transfers that bypass this leave funds permanently locked (no record → no distribution path).
- `DistributeProtocolFee` only distributes what is registered in `tokenListWithAmount`. Direct transfers to the protocol fee address without registration are unrecoverable.
- Fee collection addresses must be validated — sending to `""` or an invalid address loses funds.
- All distribution functions must handle token transfer failures without corrupting the registered balance.
- The gov/staker share of every fee is bucketed under the accrual epoch in force (`accrualBuckets[tokenPath][epoch]`). Only gov/staker may call `AdvanceAccrualEpoch` (on every stake change) and `ConsumeAccrualBuckets` (on collect, oldest epoch first). Clearing a bucket anywhere else strands that share.
- `reservedTokens` and `accrualPendingTokens` are tree-backed sets: settle one token without rewriting the whole set.

## Audit Finding (M-06)

`CollectFee` withdrawal fees were not tracked (resolved). Any future code path that transfers tokens to the protocol_fee realm without calling `AddToProtocolFee` creates a permanent balance discrepancy. Grep for every `SafeGRC20Transfer` targeting the protocol_fee realm address and verify `AddToProtocolFee` is called atomically.

## Pitfalls

- Fee transfer without `AddToProtocolFee` → fees permanently locked.
- Direct transfer to protocol_fee realm without registration → excess is unrecoverable.
- Advancing the accrual epoch without a matching gov/staker stake record → buckets attributed to a stake distribution that was never recorded.
