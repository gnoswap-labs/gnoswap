# Staker Module (`v1/staker/`)

Stakes LP NFTs, distributes GNS emissions and external incentives.

## Key Files

| File | Purpose |
|------|---------|
| `staker.gno` | Core staking logic |
| `claimable_reward.gno` | Claimable reward ledger and payout |
| `external_incentive.gno` | External incentive management |
| `reward_calculation*.gno` | Reward computation |
| `calculate_pool_position_reward.gno` | Per-position reward calculation |
| `type.gno` | Type definitions |
| `wrap_unwrap.gno` | Token wrapping utilities |

## Rules

### Hooks
- `SetTickCrossHook`, `SetSwapStartHook`, `SetSwapEndHook` execute **inside** the swap loop.
- Hook code reads mid-swap pool state (sqrtPrice, liquidity, tick) — partially updated values. Design hooks to tolerate this.
- Hook-setting functions must check halt state (audit L-03).

### Tiers
- Tier 1 (50%) / Tier 2 (30%) / Tier 3 (20%).
- Empty tier redistributes share to remaining tiers.
- Pool removal from tier must NOT block unstake or past reward collection.

### External Incentives
- Active window: `startTimestamp <= now < endTimestamp`. Both bounds required.
- `refunded` flag prevents double-claim on `EndExternalIncentive`. Set atomically.
- `EndExternalIncentive` needs `now >= endTimestamp` and keeps the record; `CancelExternalIncentive` needs `now < startTimestamp`, removes it from the incentive tree, the per-pool start-time index and the global tree, and refunds the reward tokens plus the GNS deposit to the **creator** (never a caller-supplied address). Callable by admin, governance, or the creator. Removal is only safe before the start: discovery is bounded by the current time, so no deposit can reference a pending incentive.
- `lastCollectTime` tracked **per incentive** (not shared). Updated only after the reward is successfully settled.
- `rewardPerSecond = totalReward / duration` — integer truncation leaves dust. Verify dust does not accumulate into locked balance.

### Reward settlement vs payout
- `settlePositionReward` does the accounting (cursors, incentive draw-down, ledger credit) and performs **no** token transfer and no reward-token cross-call. Keep it that way: it is what makes withdrawal independent of payout.
- `UnStakeToken` settles only. It must never transfer a reward or call `MintAndDistributeGns`, or a drained reserve / misbehaving reward token would lock the NFT in the staker.
- `payoutClaimableRewards` is best-effort per token: a token the ROLE_STAKER reserve cannot cover stays in the ledger (`InsufficientClaimableReward` event) instead of aborting.
- Protocol fees are recorded as pending at settlement (`accrueStakingRewardFee`) and forwarded during payout, and only when the reserve covers the fee **and** the receiver's amount.

### Warmup
- Final warmup tier must be `math.MaxInt64`. Finite value → panic when block time passes it.
- Warmup percentages must sum to ≤ 100 at any point.

## Pitfalls

- Finite final warmup tier → panic at runtime.
- Pool tier removal blocks unstake → NFTs permanently locked.
- Reward transfer reintroduced into the unstake path → drained reserve locks NFTs.
- `lastCollectTime` shared across incentives → wrong reward amounts.
- `referrer` not forwarded → lost referral attribution.
- `rewardPerSecond` dust not handled → small balance permanently locked.
