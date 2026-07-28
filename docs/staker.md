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
- `lastCollectTime` tracked **per incentive** (not shared). Updated only after successful transfer.
- `rewardPerSecondX128 = (totalReward << 128) / duration` — reward rate is scaled by 2^128 (Q128) before storage, so the per-second truncation collapses to at most 1 wei over the incentive's full duration instead of accumulating as dust.
- External incentive ending currently refunds reward tokens and the GNS deposit to the explicit `refundAddress` argument, not implicitly to the creator.

### Warmup
- Final warmup tier must be `math.MaxInt64`. Finite value → panic when block time passes it.
- Warmup percentages must sum to ≤ 100 at any point.

## Pitfalls

- Finite final warmup tier → panic at runtime.
- Pool tier removal blocks unstake → NFTs permanently locked.
- `lastCollectTime` shared across incentives → wrong reward amounts.
- `referrer` not forwarded → lost referral attribution.
- Assuming `rewardPerSecond` is a plain integer (pre-Q128 dust bug) instead of the current Q128-scaled `rewardPerSecondX128` → wrong reward-rate math when reading the raw value.
- Documenting incentive refunds as creator-only → wrong operator/admin expectations when `refundAddress` is supplied.
