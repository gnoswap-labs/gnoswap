# Int64 Overflow/Underflow Vulnerabilities in Staker Package

## Summary
This document identifies all int64 arithmetic operations in the staker package that could potentially overflow or underflow.

## Critical Vulnerabilities

### 1. **reward_calculation_pool.gno**

#### Line 241: Block Difference Calculation
```go
blockDiff := currentHeight - oldAccHeight
```
- **Risk**: If `oldAccHeight > currentHeight`, this will underflow
- **Impact**: Could cause incorrect reward calculations

#### Line 364, 373: Reward Accumulation
```go
self.rewards[i] += int64(rewardAcc.Uint64())
```
- **Risk**: Converting uint64 to int64 can overflow if value > MaxInt64
- **Impact**: Rewards could become negative or wrap around

#### Line 429: Unclaimable Accumulation
```go
self.unclaimableAcc += int64(unclaimableHeights) * self.CurrentReward(self.lastUnclaimableHeight)
```
- **Risk**: Multiplication can overflow with large block differences and rewards
- **Impact**: Unclaimable rewards could overflow

### 2. **type.gno**

#### Line 54: Reward Spent Calculation
```go
blocks := currentHeight - uint64(self.startHeight)
rewardSpent := int64(blocks) * self.rewardPerBlock
```
- **Risk**: Multiplication overflow with large block counts
- **Impact**: Incorrect reward accounting

#### Line 72: Reward Left Calculation
```go
blocks := uint64(self.endHeight) - currentHeight
rewardLeft := int64(blocks) * self.rewardPerBlock
```
- **Risk**: Same multiplication overflow risk
- **Impact**: Incorrect remaining reward calculation

#### Lines 94-95: Block Height Calculations
```go
blocksLeftUntilStartHeight := (startTimestamp - currentTime) * 1000 / msPerBlock
blocksLeftUntilEndHeight := (endTimestamp - currentTime) * 1000 / msPerBlock
```
- **Risk**: Multiplication by 1000 can overflow for large timestamp differences
- **Impact**: Incorrect height calculations

### 3. **reward_calculation_incentives.gno**

#### Line 191: Unclaimable Reward Calculation
```go
return int64(blocks) * incentive.rewardPerBlock
```
- **Risk**: Multiplication overflow with large block counts
- **Impact**: Incorrect unclaimable reward amount

### 4. **reward_calculation_warmup.gno**

#### Lines 24-26: Warmup Duration Calculations
```go
blocksIn5Days := int64(5 * blocksInDay)
blocksIn10Days := int64(10 * blocksInDay)
blocksIn30Days := int64(30 * blocksInDay)
```
- **Risk**: Multiplication could overflow for large `blocksInDay`
- **Impact**: Incorrect warmup periods

#### Line 70-72: Next Warmup Height
```go
nextWarmupHeight := currentHeight + warmup.BlockDuration
if nextWarmupHeight < 0 {
    nextWarmupHeight = math.MaxInt64
}
```
- **Risk**: Addition overflow detection, but sets to MaxInt64
- **Impact**: Could cause issues in downstream calculations

### 5. **staker.gno**

#### Lines 447, 449: External Reward Processing
```go
incentive.rewardAmount -= rewardAmount
toUserExternalReward[rewardToken] += rewardAmount
```
- **Risk**: Subtraction could underflow if rewardAmount > incentive.rewardAmount
- **Impact**: Negative reward amounts

#### Lines 458-460: Penalty Processing
```go
incentive.rewardAmount -= externalPenalty
incentive.rewardLeft += externalPenalty
toUserExternalPenalty[rewardToken] += externalPenalty
```
- **Risk**: Same underflow/overflow risks
- **Impact**: Incorrect penalty accounting

#### Lines 490, 494, 501: Total Emission Tracking
```go
totalEmissionSent += toUser
totalEmissionSent += reward.InternalPenalty
totalEmissionSent += unClaimableInternal
```
- **Risk**: Accumulation could overflow over time
- **Impact**: Incorrect emission tracking

#### Line 480: Fee Calculation
```go
"rewardToFee", formatInt(int64(rewardAmount)-toUser)
```
- **Risk**: Subtraction could underflow if toUser > rewardAmount
- **Impact**: Incorrect fee reporting

### 6. **external_incentive.gno**

#### Line 197: Refund Calculation
```go
refund += int64(pool.incentives.calculateUnclaimableReward(ictv.incentiveId))
```
- **Risk**: Addition could overflow with large unclaimable rewards
- **Impact**: Incorrect refund amount

### 7. **json.gno**

#### Line 167: Stake Duration
```go
stakeDuration = uint64(std.ChainHeight() - deposit.stakeHeight)
```
- **Risk**: Could underflow if chain height < stake height (shouldn't happen but worth checking)
- **Impact**: Incorrect duration display

## Recommendations

1. **Use Checked Arithmetic**: Implement overflow/underflow checks for all arithmetic operations
2. **Use Larger Types**: Consider using uint256 for intermediate calculations
3. **Add Bounds Checking**: Validate inputs before arithmetic operations
4. **Implement SafeMath**: Create helper functions for safe arithmetic operations
5. **Add Assertions**: Assert invariants before and after calculations

## Priority Fixes

1. **High Priority**: Fix multiplication overflows in reward calculations (type.gno lines 54, 72, 94-95)
2. **High Priority**: Fix accumulation overflows (reward_calculation_pool.gno line 429)
3. **Medium Priority**: Fix subtraction underflows in incentive processing (staker.gno lines 447-460)
4. **Medium Priority**: Add overflow protection to emission tracking (staker.gno lines 490, 494, 501)
5. **Low Priority**: Add defensive checks for block height calculations

## Test Coverage

The `precision_vulnerability_test.gno` file demonstrates several of these issues:
- Reward calculation overflow (lines 92-107)
- U256 to int64 conversion overflow (lines 109-123)
- Precision loss in warmup calculations (lines 125-168)
- Fee rounding exploits (lines 170-215)
- External incentive division precision loss (lines 217-263)