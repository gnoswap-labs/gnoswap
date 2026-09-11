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
- A checkpoint's window is final: a zero user reward is left to accrue only while the position is staked, so delivery must still pay the penalty and advance the cursor for a checkpoint.
- `EndExternalIncentive` refuses while an unstaked position still owes a reward from **that** incentive: its share has not been drawn down yet, so refunding would pay it to the creator. The count is keyed by incentive id, never by pool - a pool-wide guard would let one blocked incentive take every other incentive in the pool down with it.
- An incentive's reward amount only ever decreases, so a checkpoint owed more than the incentive holds can never be paid. Such a debt is **forfeited** on collect (`ForfeitUncollectedIncentiveReward`), releasing both the position's re-staking and the incentive's refund; keeping it pending would lock both forever with no escape path.
- The checkpoint also pins the **unstaking fee rate**: the window closed under it, and collect is permissionless, so a later fee change must not apply retroactively.
- A checkpoint delivery refuses when its cursor already reached the window's close. Collect computes amounts once and then transfers per source, and checkpoint collects are permissionless, so a re-entering call between transfers must not get a precomputed amount replayed.
- **Invariant the deferred collect depends on**: every path that changes the tier layout must materialize the reward cache of all tiered pools first, at the current time (`changeTier` does this via `cacheReward`). A tier change that skips it would let `resolveInternalRewardSegments` re-rate a checkpoint's closed window with the new layout.

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
