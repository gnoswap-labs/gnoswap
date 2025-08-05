# Block-Based to Timestamp-Based Conversion Guide

This guide documents the complete process, lessons learned, and best practices for converting Gnoswap modules from block-based to timestamp-based reward calculations.

## Overview

The goal is to replace block-based reward calculations with timestamp-based calculations while maintaining block heights for state tracking. This ensures rewards are distributed based on actual time elapsed rather than block count, making the system more predictable and fair regardless of block time variations.

## Key Principles

1. **Dual Tracking**: Maintain both timestamps AND block heights
   - Use timestamps for reward calculations
   - Keep block heights for state tracking and validation
   - Never remove height fields - they're still needed for other purposes

2. **Time Source**: Use `time.Now().Unix()` to get current block time in Gno
   - This returns the block timestamp, not wall clock time
   - Each block has a fixed timestamp that doesn't change

3. **Field Naming**: Rename "PerBlock" to "PerSecond" consistently
   - `rewardPerBlock` → `rewardPerSecond`
   - `distributeAmountPerBlock` → `distributeAmountPerSecond`
   - Update all references in comments and documentation

## Step-by-Step Process

### 1. Initial Analysis
```bash
# Search for all block-based calculations
grep -r "PerBlock\|perBlock\|blockDuration\|blockCount" contract/r/gnoswap/<module>/
grep -r "BlockHeight()" contract/r/gnoswap/<module>/ | grep -v "test"

# Look for reward calculation functions
grep -r "calculate.*Reward\|distribute.*Amount" contract/r/gnoswap/<module>/
```

### 2. Identify Key Files
Typical files that need changes:
- `reward_manager.gno` - Core reward distribution logic
- `project_tier.gno` or equivalent tier management
- `*_deposit.gno` - Deposit handling
- `*_withdraw.gno` - Withdrawal handling
- Test files for each of the above

### 3. Field Renaming Strategy

**Phase 1: Simple Renames**
```go
// Before
distributeAmountPerBlockX128 *u256.Uint

// After  
distributeAmountPerSecondX128 *u256.Uint
```

**Phase 2: Add Time Fields**
```go
// Add alongside existing height fields
type RewardManager struct {
    // Existing
    accumulatedHeight     int64
    distributeStartHeight int64
    distributeEndHeight   int64
    
    // New additions
    accumulatedTime     int64  // Last calculation timestamp
    distributeStartTime int64  // Distribution start timestamp
    distributeEndTime   int64  // Distribution end timestamp
}
```

### 4. Update Calculation Logic

**Key Pattern: Replace block duration with time duration**
```go
// Before
blockDuration := currentHeight - accumulatedHeight
totalRewardX128 := u256.Zero().Mul(u256.NewUintFromInt64(blockDuration), rewardPerBlockX128)

// After
timeDuration := currentTime - accumulatedTime
totalRewardX128 := u256.Zero().Mul(u256.NewUintFromInt64(timeDuration), rewardPerSecondX128)
```

**Common Functions to Update:**
1. `calculateRewardPerDepositX128()` - Add time parameter
2. `updateRewardPerDepositX128()` - Add time parameter
3. `updateDistributeAmountPerSecond()` - Use time duration

### 5. Function Signature Updates

**Add time parameter to key functions:**
```go
// Before
func (r *RewardManager) updateRewardPerDepositX128(totalDepositAmount int64, height int64) error

// After
func (r *RewardManager) updateRewardPerDepositX128(totalDepositAmount int64, height int64, time int64) error
```

**Update all callers:**
```go
// Before
err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight)

// After
currentTime := time.Now().Unix()
err = rewardManager.updateRewardPerDepositX128(projectTier.CurrentDepositAmount(), currentHeight, currentTime)
```

## Common Pitfalls & Solutions

### 1. Missing Time Parameter in Callers
**Error**: "not enough arguments in call to updateRewardPerDepositX128"
**Solution**: Add `time.Now().Unix()` as parameter
```go
currentTime := time.Now().Unix()
err = rewardManager.updateRewardPerDepositX128(amount, height, currentTime)
```

### 2. Zero Division Protection
**Issue**: When duration is 0 (same start/end time)
**Solution**: Add validation
```go
if timeDuration <= 0 {
    return
}
```

### 3. Constructor Updates
**Issue**: NewRewardManager needs time parameters
**Solution**: Add start/end time parameters
```go
func NewRewardManager(
    totalDistributeAmount int64,
    distributeStartHeight int64,
    distributeEndHeight int64,
    distributeStartTime int64,    // New
    distributeEndTime int64,       // New
    currentHeight int64,
    currentTime int64,             // New
) *RewardManager
```

### 4. Test Environment Limitations
**Issue**: `time.Now()` doesn't advance with `testing.SkipHeights()` in Gno
**Solution**: 
- Focus on unit tests with explicit time values
- Avoid integration tests that depend on time advancement
- Use helper functions to simulate time passing

## Test Environment Setup

### Running Tests

**Step 1: Setup the test environment**
```bash
# From the project root directory
python setup.py

# This copies all modules to ~/gno/examples/gno.land/
# Including dependencies like rbac, test tokens, etc.
```

**Step 2: Run tests**
```bash
# Run all tests for a module(launchpad for example)
gno test ~/gno/examples/gno.land/r/gnoswap/v1/launchpad/... -root-dir ~/gno -v

# Run specific test by name
gno test ~/gno/examples/gno.land/r/gnoswap/v1/launchpad/... -root-dir ~/gno -run=TestTimestampBased -v

# Run tests matching a pattern
gno test ~/gno/examples/gno.land/r/gnoswap/v1/launchpad/... -root-dir ~/gno -run="Timestamp|VaryingBlockTimes" -v
```

**Common Test Commands:**
```bash
# Quick test run (no verbose)
gno test ~/gno/examples/gno.land/r/gnoswap/v1/launchpad/... -root-dir ~/gno

# Verbose output (recommended for debugging)
gno test ~/gno/examples/gno.land/r/gnoswap/v1/launchpad/... -root-dir ~/gno -v

# Run a specific test file
gno test ~/gno/examples/gno.land/r/gnoswap/v1/launchpad/reward_manager_test.gno -root-dir ~/gno -v
```

### Important Notes for Testing

1. **Module Path**: Use the full path after setup.py copies files:
   - `~/gno/examples/gno.land/r/gnoswap/v1/<module>/...`

2. **Root Directory**: Always include `-root-dir ~/gno` flag

3. **Test Isolation**: Tests should restore original state after running:
   ```go
   // Capture original state
   origProjects := projects
   origManagers := projectTierRewardManagers
   
   // Run test...
   
   // Restore state
   projects = origProjects
   projectTierRewardManagers = origManagers
   ```

### Troubleshooting Test Issues

**Error: "use of builtin cross not in function call"**
- This is an RBAC module issue
- Solution: Ensure Gno is properly installed and setup.py has run

**Error: "cannot use int(height) (value of type int) as int64"**
- Type conversion issue
- Solution: Remove unnecessary int() conversions

**Error: Package not found**
- Module not copied to correct location
- Solution: Re-run `python setup.py`

## Testing Strategy

### 1. Core Test Scenarios
```go
// Test varying block times
func TestRewardCalculation_VaryingBlockTimes(t *testing.T) {
    // Test fast blocks (1 second per block)
    // Test slow blocks (20 seconds per block)
    // Test irregular blocks (mixed timing)
}

// Test time boundaries
func TestRewardCalculation_TimeBoundaries(t *testing.T) {
    // Before distribution start
    // Exactly at start
    // Exactly at end
    // After distribution end
}
```

### 2. Helper Functions for Tests
```go
// Calculate end time based on tier type
func calculateEndTimeByTierType(tierType int64, startTime int64, startHeight int64, averageBlockTimeMs int64) *BlockTimeInfo {
    endTime := startTime + projectTierDurationTimes[tierType]
    return newBlockTimeInfoByTimeAndAverageBlockTimeMs(
        startTime,
        startHeight,
        endTime,
        averageBlockTimeMs,
    )
}
```

### 3. Test Data Setup
```go
// Create test reward manager with time parameters
rewardManager := NewRewardManager(
    1000,  // total amount
    100,   // start height
    200,   // end height
    1000,  // start time
    1200,  // end time (200 seconds duration)
    150,   // current height
    1100,  // current time
)
```

## Verification Checklist

- [ ] All "PerBlock" fields renamed to "PerSecond"
- [ ] Time fields added to data structures
- [ ] Calculation functions use time duration instead of block duration
- [ ] All function calls updated with time parameters
- [ ] Tests verify time-based calculations work correctly
- [ ] Tests cover varying block time scenarios
- [ ] No TODO comments or temporary workarounds
- [ ] Documentation and comments updated
- [ ] All tests passing

## Common Errors and Fixes

### 1. Type Conversion Issues
**Error**: "cannot use int(height) (value of type int) as int64 value"
**Fix**: Remove unnecessary int() conversions

### 2. Missing Struct Fields
**Error**: "unknown field claimableBlockTimeInfo in struct literal"
**Fix**: Ensure all required fields are initialized in test data

### 3. Nil Pointer Dereference
**Error**: "invalid memory address or nil pointer dereference"
**Fix**: Initialize all required fields, especially:
- `claimableBlockTimeInfo` in RewardState
- `distributeAmountPerSecondX128` in ProjectTier

### 4. Error Message Format
**Note**: Error messages with `%!d((unhandled))` are normal for u256.Uint formatting
This is not a bug - it's how ufmt.Sprintf handles the type

## Module-Specific Considerations

### For Staker Module
- More complex than launchpad due to multiple reward pools
- May have external reward calculations
- Check for governance staking interactions

### For Other Modules
- Identify module-specific reward distribution patterns
- Check for inter-module dependencies
- Verify all reward paths are updated

## Final Tips

1. **Work incrementally**: Rename fields first, then update logic
2. **Run tests frequently**: Catch issues early
3. **Check all callers**: Use IDE/grep to find all function calls
4. **Preserve behavior**: Ensure rewards calculate the same for constant block times
5. **Document changes**: Update comments and create summary files

## Example Conversion Summary

For the launchpad module, the conversion involved:
- 11 files modified
- ~30 field renames
- 3 new timestamp fields added to RewardManager
- 5 calculation functions updated
- 6 new test cases added
- 0 breaking changes to external APIs

The key insight is that timestamps make reward distribution predictable and fair, regardless of block time variations, while maintaining backward compatibility for state tracking.

## Additional Testing Considerations

### Gno Test Environment Limitations

1. **time.Now() Behavior**:
   - Returns the current block's timestamp
   - Does NOT advance with `testing.SkipHeights()`
   - Each call within same block returns same value

2. **testing.SkipHeights(n)**:
   - Advances block height by n
   - Advances time by n * 5 seconds (5 seconds per block)
   - But `time.Now()` doesn't reflect this advancement

3. **Workaround for Time-Based Tests**:
   ```go
   // Instead of relying on time.Now() advancement
   // Use explicit time values in tests
   
   // Simulate time passing
   startTime := int64(1000)
   currentTime := startTime + 100  // 100 seconds later
   
   // Create test objects with specific times
   rewardManager := NewRewardManager(
       totalAmount,
       startHeight,
       endHeight,
       startTime,
       endTime,
       currentHeight,
       currentTime,  // Explicit time instead of time.Now()
   )
   ```

4. **Test Token Setup**:
   ```go
   // For tests requiring GNS tokens
   // Look for existing patterns in staker module:
   gnsTransfer := func(to std.Address, amount uint64) {
       testing.SetRealm(adminRealm)
       testing.SetOrigSend(std.Coins{{"ugnot", int64(amount)}}, nil)
       banker := std.GetBanker(std.BankerTypeRealmSend)
       banker.SendCoins(consts.ADMIN_ADDR, to, std.Coins{{"gns", int64(amount)}})
   }
   ```

5. **MockDeposit Issue**:
   - If you encounter "undefined: MockDeposit"
   - Use `NewDeposit()` function instead of MockDeposit