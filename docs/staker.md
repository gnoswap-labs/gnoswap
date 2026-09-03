# Staker Module (`v1/staker/`)

Stakes LP NFTs, distributes GNS emissions and external incentives.

## Key Files

| File | Purpose |
|------|---------|
| `staker.gno` | Core staking logic |
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
- `UnStakeToken` only records an exit checkpoint. It must never calculate or pay a reward, or a long unclaimed window would make a position unwithdrawable.
- The checkpoint pins the exit tick, the two boundary ticks (the unstake prunes them) and the tier context (a later tier change would re-rate the closed window). `PoolResolver` reads through that pin only on the checkpoint path.
- `Collect*` accept a checkpoint and collect per source; the checkpoint is dropped when every source is done. A checkpoint collect is permissionless, since it can only pay the position's owner.
- `EndExternalIncentive` refuses while an unstaked position of the pool still owes an incentive: its share has not been drawn down yet, so refunding would pay it to the creator.

### External Incentives
- Active window: `startTimestamp <= now < endTimestamp`. Both bounds required.
- `refunded` flag prevents double-claim on `EndExternalIncentive`. Set atomically.
- `EndExternalIncentive` needs `now >= endTimestamp` and keeps the record; `CancelExternalIncentive` needs `now < startTimestamp`, removes it from the incentive tree, the per-pool start-time index and the global tree, and refunds the reward tokens plus the GNS deposit to the **creator** (never a caller-supplied address). Callable by admin, governance, or the creator. Removal is only safe before the start: discovery is bounded by the current time, so no deposit can reference a pending incentive.
- `lastCollectTime` tracked **per incentive** (not shared). Updated only after successful transfer.
- `rewardPerSecond = totalReward / duration` — integer truncation leaves dust. Verify dust does not accumulate into locked balance.

### Warmup
- Final warmup tier must be `math.MaxInt64`. Finite value → panic when block time passes it.
- Warmup percentages must sum to ≤ 100 at any point.

## Pitfalls

- Finite final warmup tier → panic at runtime.
- Pool tier removal blocks unstake → NFTs permanently locked.
- Reward calculation reintroduced into the unstake path → a long unclaimed window locks NFTs.
- Refunding an incentive while positions are uncollected → their reward is paid to the creator instead.
- `lastCollectTime` shared across incentives → wrong reward amounts.
- `referrer` not forwarded → lost referral attribution.
- `rewardPerSecond` dust not handled → small balance permanently locked.
