# Launchpad Module (`r/gnoswap/launchpad/v1/`)

Token distribution and time-locked GNS deposits with project-token rewards.

## Rules

- Tier allocation is integer arithmetic: for the 30-day and 90-day tiers, `tierAmount = SafeMulDivInt64(depositAmount, tierRatio, 100)`; the 180-day tier receives the remaining amount so the tier allocations total the deposit.
- Reward accounting uses Q128 fixed-point indices. The per-second rate is `(totalDistributeAmount << 128) / (endTime - startTime)`, and each update adds `elapsedSeconds * rate / totalStaked` to the cumulative index. A claim calculates `((accumulatedIndex - priceDebt) * depositAmount) >> 128`, then subtracts what that deposit already claimed.
- Integer division and Q128 truncation are part of the on-chain result; a range that reaches a tier end is capped by that end.
- A project reward becomes claimable at `createdAt + 1 day`, capped at the tier end. `CollectDepositGns` settles any claimable project reward before returning the original GNS principal and is available only strictly after the tier end.
- `CreateProject` is admin-or-governance authorized. Deposits, reward claims, and principal withdrawals are restricted to the deposit owner. The administrative refund is admin-only, requires an ended project, and transfers only the remaining balance to its supplied recipient after reserving active depositor claims.
- Condition expressions are split by `*PAD*`; an off-chain caller must use that delimiter rather than commas.
- Checks-effects-interactions ordering must be preserved around token transfers and reward-state updates.
- Project and deposit values must remain consistent with the stored state; do not infer deposit amounts from a current token balance.

## Pitfalls

- Using a single vesting-rate formula for all tiers misstates the 180-day allocation and ignores integer rounding.
- Off-chain calculators that use exclusive seconds, omit Q128 shifts, or fail to cap at the tier end can disagree with claims.
- Treating `CollectDepositGns` as principal-only misses its reward-settlement side effect.
- A halted emission call returns a soft `(0, false)` result; callers must decide whether their operation requires minted emission.
- Bypassing owner/admin checks, condition validation, or CEI can expose deposits or project-token balances.
