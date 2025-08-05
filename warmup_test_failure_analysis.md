# Warmup Test Failure Analysis

## Problem Summary

After converting the Gnoswap staker module from block-based to timestamp-based reward distribution, two warmup tests are failing:

1. **TestCanonicalWarmup_1**: Expected 5000000000, got 2999999999
2. **TestCanonicalWarmup_2**: Expected 25000000000, got 11999999999

The rewards are consistently coming out lower than expected by approximately 40% and 52% respectively.

## Root Cause Analysis

### 1. Time-Based vs Block-Based Calculation Mismatch

The core issue appears to be a mismatch between how the canonical test calculates rewards (per-block) and how the implementation now calculates them (over time intervals).

**Canonical Test Expectation:**
- Uses `PerBlockEmission = 1000000000`
- Calculates expected rewards as: `PerBlockEmission * warmupRatio / 100`
- Runs for 10 blocks (10 seconds with MsPerBlock = 1000ms)

**Current Implementation:**
- Now uses timestamps instead of block heights
- Accumulates rewards over time intervals
- But the reward accumulation logic may not be properly accounting for the reward rate

### 2. Global Reward Ratio Accumulation Issue

The `calculateGlobalRewardRatioAccumulation` function calculates accumulation based on time differences but doesn't incorporate the actual reward rate:

```go
// Current implementation (problematic)
acc = timeDiff * q128 / currentStakedLiquidity
```

This formula only tracks time passage, not the actual rewards being distributed per second.

### 3. Reward Flow Analysis

The reward calculation flow is:
1. `cacheInternalReward` is called with a reward amount (emission)
2. `updateGlobalRewardRatioAccumulation` updates the accumulation
3. `calculateInternalReward` uses the accumulation to calculate position rewards
4. `rewardPerWarmup` multiplies by `rewardPerSecond`

The issue is that the accumulation and the reward rate multiplication are happening at different stages, leading to incorrect calculations.

## Attempted Solutions

### Attempt 1: Pass Reward Rate to Accumulation Functions

**What I tried:**
- Modified `calculateGlobalRewardRatioAccumulation` to accept a `rewardPerSecond` parameter
- Updated the accumulation formula to: `(timeDiff * rewardPerSecond * q128) / currentStakedLiquidity`
- Updated all callers to pass the reward rate

**Why it didn't work:**
- The function is called from multiple places with different contexts
- `modifyDeposit` calls it when liquidity changes (no reward rate needed)
- `cacheInternalReward` calls it when caching rewards (has reward rate)
- Mixing these two use cases in one function created complexity

### Attempt 2: Separate Functions for Different Use Cases

**What I tried:**
- Created `calculateGlobalRewardRatioAccumulationWithReward` for reward caching
- Kept original function for liquidity changes
- Updated `cacheInternalReward` to update accumulation before changing the reward rate

**Current status:**
- This approach is partially implemented but not yet tested
- The logic tries to update accumulation with the old reward rate before caching the new one

### Attempt 3: Debug Output Analysis

**What I found:**
- Added debug logging to trace the exact values being used
- Discovered that `CurrentReward` returns the per-pool reward amount
- The canonical test expects this to be applied per block
- But the implementation now needs to handle per-second calculations

## Key Insights

1. **Emission Conversion**: The emission value needs to be converted from per-block to per-second, but the current MsPerBlock = 1000ms (1 second) means they should be equivalent.

2. **Accumulation Timing**: The accumulation needs to include the reward rate at the time of accumulation, not just track time differences.

3. **Test Expectations**: The canonical tests were written for block-based rewards and expect specific values based on block counts. These expectations may need adjustment for time-based rewards.

## Next Steps

1. **Fix the accumulation calculation** to properly include reward rates
2. **Ensure consistent per-second calculations** throughout the system
3. **Update test expectations** if necessary to match time-based calculations
4. **Add comprehensive debug logging** to trace exact calculation values
5. **Verify the warmup ratio application** is working correctly with time-based rewards

## Related Files

- `reward_calculation_pool.gno`: Contains the accumulation logic
- `reward_calculation_canonical_test.gno`: The failing tests
- `reward_calculation_canonical_env_test.gno`: Test environment setup
- `reward_calculation_warmup.gno`: Warmup ratio application
- `reward_calculation_pool_tier.gno`: Pool tier reward distribution