# Staker

Liquidity mining and reward distribution for LP positions.

## Overview

Staker manages distribution of internal (GNS emission) and external (user-provided) rewards to staked LP positions, with time-weighted rewards and warmup periods.

## Configuration

- **Deposit GNS Amount**: 100,000 GNS per external incentive (default; governance-adjustable)
- **Minimum Reward Amount**: 1,000 token units (default for external incentive creation)
- **Unstaking Fee**: 1% default (100 basis points; configurable from 0 to 10%)
- **Internal Pool Tiers**: 1, 2, or 3 (assigned per pool); external-only pools can also be stakeable
- **Warmup Schedule**: 30/50/70/100% over default cumulative windows of 0-5, 5-15, 15-45, and 45+ days
- **External Token Policy**: Approved reward tokens; pool-pair tokens are also accepted for their own pool unless explicitly denied

## Core Features

### Internal Rewards (GNS Emission)

- Allocated to tiered pools (tiers 1, 2, 3)
- Split across tiers by TierRatio
- Distributed proportionally to in-range liquidity
- Unclaimed rewards go to community pool

### External Rewards (User Incentives)

- Created for specific pools
- Constant reward per second over the incentive window; the stored rate is Q128-scaled as `(rewardAmount << 128) / duration`
- Proportional to staked liquidity
- `EndExternalIncentive` returns only the unclaimable/remainder portion and GNS deposit to its explicit refund address; rewards still owed by live positions remain claimable

### Warmup Periods

Every staked position progresses through warmup periods. The default finite durations are 5, 10,
and 30 days, followed by a final `math.MaxInt64` tier:

- 0-5 days: 30% of the calculated reward
- 5-15 days: 50% of the calculated reward
- 15-45 days: 70% of the calculated reward
- 45+ days: 100% of the calculated reward

Governance may change the finite durations. Warmup ratios are applied before the staking-reward fee:
internal GNS penalties go to the community pool, while external penalties accumulate on the
incentive and are collected separately to an explicit address after `EndExternalIncentive`.

## Key Functions

### `StakeToken`

Stakes LP position NFT to earn rewards.

### `UnStakeToken`

Unstakes a position and records an exit checkpoint for its rewards. It neither calculates nor
pays them: withdrawing must never depend on the reward side.

### `CollectReward`

Collects accumulated rewards. Takes a position that was unstaked without collecting as well as a
staked one, so withdrawing is `UnStakeToken` plus one collect. A collect on an unstaked position
is permissionless, since it can only ever pay that position's owner.

### `CreateExternalIncentive`

Creates an external reward program for a specific pool. Any caller may create one after satisfying
the reward-token allowlist/denial, duration, start-time, reward-minimum, and GNS-deposit checks.

### `EndExternalIncentive`

Ends an incentive after its end timestamp and finalizes its refundable unclaimable/remainder
amount. The reward tokens and GNS deposit are sent to the caller-supplied `refundAddress`; only
the creator or admin may call it, and an outstanding exit checkpoint for that incentive blocks ending.

### `CancelExternalIncentive`

Removes an incentive that has not started and refunds its reward tokens and GNS deposit to the
creator. Callable by admin, governance, or the creator; the reward-token refund is capped by the
balance held by the staker.

## Reward Calculation Logic

### Tier Ratio Distribution

Emission split across tiers based on active pools:

```
If only tier 1 has pools:    [100%, 0%, 0%]
If tiers 1 & 3 have pools:   [80%, 0%, 20%]
If tiers 1 & 2 have pools:   [70%, 30%, 0%]
If all tiers have pools:     [50%, 30%, 20%]
```

Mathematical representation:

```math
TierRatio(t) =
  [100, 0, 0]  if Count(2) = 0 ∧ Count(3) = 0
  [80, 0, 20]  if Count(2) = 0
  [70, 30, 0]  if Count(3) = 0
  [50, 30, 20] otherwise
```

### Pool Reward Formula

```math
poolReward(pool) = (emission × TierRatio[tier(pool)] / 100) / Count(tier(pool))
```

Here `emission` is the already-allocated per-second GNS amount returned by the emission module
for liquidity stakers. It is split by the tier percentage and then divided among pools in that
tier:

```math
emission = GetStakerEmissionAmountPerSecond()
```

### Position Reward Calculation

The reward for each position is calculated through:

1. **Resolve the persisted/halving per-second reward schedule** (read-only)
2. **Retrieve position state** from deposit records or an exit checkpoint
3. **Calculate internal rewards** if the pool has an internal tier
4. **Calculate external rewards** for the incentive IDs
5. **Apply warmup ratios and penalties** based on stake duration

Collection may separately advance reward caches and persist newly discovered incentive IDs; the
read-only calculation itself does not write those caches.

Mathematical formula for total reward ratio:

```math
TotalRewardRatio(s,e) = Σ[i=0 to m-1] ΔRaw(αᵢ, βᵢ) × rᵢ

where:
  αᵢ = max(s, Hᵢ₋₁)
  βᵢ = min(e, Hᵢ)

ΔRaw(a, b) = CalcRaw(b) - CalcRaw(a)

CalcRaw(h) =
  L(h) - U(h)           if tick(h) < ℓ
  U(h) - L(h)           if tick(h) ≥ u
  G(h) - (L(h) + U(h))  otherwise

where:
  L(h) = tickLower.OutsideAccumulation(h)
  U(h) = tickUpper.OutsideAccumulation(h)
  G(h) = globalRewardRatioAccumulation(h)
  ℓ = tickLower.id
  u = tickUpper.id
```

Final position reward:

```math
finalReward = TotalRewardRatio × poolReward × positionLiquidity
            = ∫[s to e] (poolReward × positionLiquidity) / TotalStakedLiquidity(h) dh
```

### Tick Cross Hook

When price crosses an initialized tick with staked positions:

1. **Updates staked liquidity** - Adjusts total staked liquidity
2. **Updates reward accumulation** - Recalculates `globalRewardRatioAccumulation`
3. **Manages unclaimable periods** - Starts/ends periods with no in-range liquidity
4. **Updates tick accumulation** - Adjusts `CurrentOutsideAccumulation`

The `globalRewardRatioAccumulation` tracks the integral:

```math
globalRewardRatioAccumulation = ∫ 1/TotalStakedLiquidity(h) dh
```

This integral is only computed when `TotalStakedLiquidity(h) ≠ 0`, enabling precise reward calculation even as liquidity changes.

### Reward State Tracking

The system maintains:

- **Global accumulation**: Tracks reward ratio across all positions
- **Tick accumulation**: Tracks rewards "outside" each tick
- **Position state**: Individual reward calculation parameters

## Usage

The proxy functions receive a realm argument. From a caller realm with `cur realm`, pass
`cross(cur)` as that first argument:

```go
// Stake an existing position
StakeToken(cross(cur), 123, "g1referrer...")

// Create an external incentive (rewardAmount is an int64 token-unit amount)
CreateExternalIncentive(
    cross(cur),
    "gno.land/r/demo/bar:gno.land/r/demo/baz:3000",
    "gno.land/r/demo/reward",
    1_000_000_000,
    startTime,
    endTime,
)

// Collect while the position is staked
CollectReward(cross(cur), 123)

// Unstake: this returns the NFT and creates an exit checkpoint; it does not collect
UnStakeToken(cross(cur), 123)

// Collect the checkpoint, either per source or all at once
CollectEmissionReward(cross(cur), 123)
CollectExternalIncentiveReward(cross(cur), 123, incentiveId)
```

## Security

- Positions locked during staking
- External incentives require GNS deposit
- Warmup periods prevent gaming
- Unclaimed rewards properly redirected
- Hook integration ensures accurate tracking
