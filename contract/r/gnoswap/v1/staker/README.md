# Staker

Liquidity mining and reward distribution for LP positions.

## Overview

Staker manages distribution of internal (GNS emission) and external (user-provided) rewards to staked LP positions, with time-weighted rewards and warmup periods.

## Configuration

- **Deposit GNS Amount**: 1,000 GNS for external incentives (default)
- **Minimum Reward Amount**: 1,000 tokens (default)
- **Unstaking Fee**: 1% (default)
- **Pool Tiers**: 1, 2, or 3 (assigned per pool)
- **Warmup Schedule**: 30/50/70/100% over 30/60/90 days
- **External Token Whitelist**: Approved reward tokens

## Core Features

### Internal Rewards (GNS Emission)
- Allocated to tiered pools (tiers 1, 2, 3)
- Split across tiers by TierRatio
- Distributed proportionally to in-range liquidity
- Unclaimed rewards go to community pool

### External Rewards (User Incentives)
- Created for specific pools
- Constant reward per block
- Proportional to staked liquidity
- Unclaimed rewards returned to creator

### Warmup Periods
Every staked position progresses through warmup periods:
- 0-30 days: 30% rewards (70% to community/creator)
- 30-60 days: 50% rewards (50% to community/creator)
- 60-90 days: 70% rewards (30% to community/creator)
- 90+ days: 100% rewards

## Key Functions

### `StakeToken`
Stakes LP position NFT to earn rewards.

### `UnStakeToken`
Unstakes position and collects all rewards.

### `CollectReward`
Collects accumulated rewards without unstaking.

### `MintAndStake`
Mints new position and stakes in single transaction.

### `CreateExternalIncentive`
Creates external reward program for specific pool.

### `EndExternalIncentive`
Ends incentive program and returns unused rewards.

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
  [1, 0, 0]        if Count(2) = 0 ∧ Count(3) = 0
  [0.8, 0, 0.2]    if Count(2) = 0
  [0.7, 0.3, 0]    if Count(3) = 0
  [0.5, 0.3, 0.2]  otherwise
```

### Pool Reward Formula

```math
poolReward(pool) = (emission × TierRatio[tier(pool)]) / Count(tier(pool))
```

Where emission is calculated as:
```math
emission = GNSEmissionPerSecond × (avgMsPerBlock/1000) × StakerEmissionRatio
```

### Position Reward Calculation

The reward for each position is calculated through:

1. **Cache pool rewards** up to current block
2. **Retrieve position state** from deposit records
3. **Calculate internal rewards** if pool is tiered
4. **Calculate external rewards** for active incentives
5. **Apply warmup penalties** based on stake duration

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

```go
// Stake existing position
StakeToken(123, "g1referrer...")

// Create external incentive
CreateExternalIncentive(
    "gno.land/r/demo/bar:gno.land/r/demo/baz:3000",
    "gno.land/r/demo/reward",
    "1000000000",  // 1000 tokens
    startTime,
    endTime,
)

// Collect rewards without unstaking
CollectReward(123)

// Unstake and collect all rewards
UnStakeToken(123)
```

## Security

- Positions locked during staking
- External incentives require GNS deposit
- Warmup periods prevent gaming
- Unclaimed rewards properly redirected
- Hook integration ensures accurate tracking