# Staker Module Timestamp Conversion - Task Categories

## Category 1: Simple Renaming/Retyping (1-to-1 Replacement)

These tasks involve straightforward renaming of variables, parameters, and fields from height to timestamp without changing the underlying logic.

### Function Parameter Renaming

1. **reward_calculation_pool.gno**
   - `NewPool(poolPath string, currentHeight int64)` → `NewPool(poolPath string, currentTime int64)`
   - `CurrentGlobalRewardRatioAccumulation(currentHeight int64)` → `CurrentGlobalRewardRatioAccumulation(currentTime int64)`
   - `CurrentTick(currentHeight int64)` → `CurrentTick(currentTime int64)`
   - `CurrentStakedLiquidity(currentHeight int64)` → `CurrentStakedLiquidity(currentTime int64)`
   - `CurrentReward(currentHeight int64)` → `CurrentReward(currentTime int64)`
   - `cacheReward(currentHeight int64, currentTierReward int64)` → `cacheReward(currentTime int64, currentTierReward int64)`
   - `cacheInternalReward(currentHeight int64, currentEmission int64)` → `cacheInternalReward(currentTime int64, currentEmission int64)`
   - `modifyDeposit(delta *i256.Int, currentHeight int64, nextTick int32)` → `modifyDeposit(delta *i256.Int, currentTime int64, nextTick int32)`
   - `startUnclaimablePeriod(currentHeight int64)` → `startUnclaimablePeriod(currentTime int64)`
   - `endUnclaimablePeriod(currentHeight int64)` → `endUnclaimablePeriod(currentTime int64)`
   - `calculateGlobalRewardRatioAccumulation(currentHeight int64, currentStakedLiquidity *u256.Uint)` → `calculateGlobalRewardRatioAccumulation(currentTime int64, currentStakedLiquidity *u256.Uint)`
   - `updateGlobalRewardRatioAccumulation(currentHeight int64, currentStakedLiquidity *u256.Uint)` → `updateGlobalRewardRatioAccumulation(currentTime int64, currentStakedLiquidity *u256.Uint)`

2. **reward_calculation_tick.gno**
   - `CurrentOutsideAccumulation(blockNumber int64)` → `CurrentOutsideAccumulation(timestamp int64)`
   - `modifyDepositLower(currentHeight int64, currentTick int32, liquidity *i256.Int)` → `modifyDepositLower(currentTime int64, currentTick int32, liquidity *i256.Int)`
   - `modifyDepositUpper(currentHeight int64, currentTick int32, liquidity *i256.Int)` → `modifyDepositUpper(currentTime int64, currentTick int32, liquidity *i256.Int)`
   - `updateCurrentOutsideAccumulation(blockNumber int64, acc *u256.Uint)` → `updateCurrentOutsideAccumulation(timestamp int64, acc *u256.Uint)`

3. **reward_calculation_warmup.gno**
   - `instantiateWarmup(currentHeight int64, currentTime int64)` → `instantiateWarmup(currentTime int64)`
   - `FindWarmup(currentHeight int64)` → `FindWarmup(currentTime int64)`

4. **reward_calculation_pool_tier.gno**
   - `applyCacheToAllPools(pools *Pools, currentBlock int64, emissionInThisInterval int64)` → `applyCacheToAllPools(pools *Pools, currentTime int64, emissionInThisInterval int64)`

### Field Renaming in Structs

1. **Pool struct (reward_calculation_pool.gno)**
   - `lastUnclaimableHeight int64` → `lastUnclaimableTime int64`

2. **PoolTier struct (reward_calculation_pool_tier.gno)**
   - `lastRewardCacheHeight int64` → `lastRewardCacheTime int64` (already exists)

3. **Deposit struct (type.gno)**
   - `stakeHeight int64` → `stakeTime int64`
   - `lastCollectHeight int64` → `lastCollectTime int64`

### UintTree Key Changes

1. **Pool struct trees**
   - `stakedLiquidity *UintTree // uint64 blockNumber -> *u256.Uint` → `// uint64 timestamp -> *u256.Uint`
   - `rewardCache *UintTree // uint64 blockNumber -> int64 gnsReward` → `// uint64 timestamp -> int64 gnsReward`
   - `globalRewardRatioAccumulation *UintTree // uint64 blockNumber -> *u256.Uint` → `// uint64 timestamp -> *u256.Uint`
   - `historicalTick *UintTree // uint64 blockNumber -> int32 tickId` → `// uint64 timestamp -> int32 tickId`

2. **Tick struct tree**
   - `outsideAccumulation *UintTree // blockNumber -> *u256.Uint` → `// timestamp -> *u256.Uint`

### Variable Renaming

1. **Local variables in functions**
   - All instances of `currentHeight`, `startHeight`, `endHeight` → `currentTime`, `startTime`, `endTime`
   - All instances of `blockNumber` → `timestamp`
   - All instances of `blockDiff` → `timeDiff`
   - All instances of `oldAccHeight` → `oldAccTime`
   - All instances of `lastHeight` → `lastTime`

---

## Category 2: Logic Modifications and Feature Changes

These tasks require actual logic changes, not just renaming.

### Q128.128 Fixed-Point Math Implementation

1. **External Incentive Calculation**
   - Change `rewardPerSecond = rewardAmount / incentiveDuration` to use Q128.128
   - Update `RewardSpent()` and `RewardLeft()` to use Q128.128 multiplication

2. **Global Accumulation Calculation**
   - Update accumulation formula to use Q128.128 precision
   - Modify division and multiplication operations

### Core Logic Changes

1. **Warmup Logic**
   - Change warmup progression from height-based to time-based
   - Update `FindWarmup()` to compare against `NextWarmupTime` instead of `NextWarmupHeight`

2. **Reward Calculation Logic**
   - `rewardPerWarmup()` - change iteration logic from height ranges to time ranges
   - `calculateInternalReward()` - update iteration to use time boundaries
   - `CalculateRewardForPosition()` - update to use time-based accumulation

3. **Unclaimable Period Logic**
   - Change from `unclaimableHeights` to `unclaimableDuration`
   - Update accumulation calculation to use time

### Feature Removal

1. **Remove Height Validation**
   - Remove height checks from `RewardSpent()` and `RewardLeft()`
   - Remove height-based state validation throughout

2. **Remove Height Fields**
   - Remove `NextWarmupHeight` from Warmup struct (keep `NextWarmupTime`)
   - Remove `startHeight`, `endHeight` from ExternalIncentive
   - Remove height parameters from function signatures after time replacements work

### New Features

1. **Time-based Iteration**
   - Implement time-based iteration for UintTree
   - Add time range queries for reward cache

2. **Timestamp-based Events**
   - Update tick crossing to use timestamps
   - Ensure position changes are indexed by timestamp