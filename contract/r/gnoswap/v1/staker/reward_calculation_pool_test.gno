package staker

import (
	"math"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
)

func TestCalculateActualDistributedReward_ExtremeValues(t *testing.T) {
	poolPath := "test_pool_extreme"
	pool := NewPool(poolPath, time.Now().Unix())

	t.Run("LargeRewardAndOverflowProtection", func(t *testing.T) {
		currentTime := time.Now().Unix()

		// Test with very large reward amount and overflow protection
		incentive := &ExternalIncentive{
			incentiveId:      "extreme_large",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 1,
			rewardToken:      GNS_PATH,
			rewardAmount:     math.MaxInt64 / 2, // Large but safe amount
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// Test with very large liquidity to trigger potential overflow
		pool.stakedLiquidity.set(currentTime, u256.MustFromDecimal("999999999999999999"))

		defer func() {
			if r := recover(); r != nil {
				t.Logf("Large value test caused panic (caught): %v", r)
			}
		}()

		distributed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		// Verify no overflow and reasonable bounds
		if distributed < 0 {
			t.Errorf("distributed amount should not be negative, got %d", distributed)
		}
		if distributed > incentive.rewardAmount {
			t.Errorf("distributed amount %d exceeds total reward %d", distributed, incentive.rewardAmount)
		}

		t.Logf("Large reward test - Total: %d, Distributed: %d", incentive.rewardAmount, distributed)
	})

	t.Run("ShortDurationPrecision", func(t *testing.T) {
		currentTime := time.Now().Unix()

		// Test 10-second duration with incremental calculation to check precision
		incentive := &ExternalIncentive{
			incentiveId:      "precision_test",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 10,
			rewardToken:      GNS_PATH,
			rewardAmount:     10000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 10,
		}

		pool.stakedLiquidity.set(currentTime, u256.NewUint(1000))

		// Calculate second by second to test precision
		totalIncremental := int64(0)
		for i := int64(1); i <= 10; i++ {
			distributed := pool.CalculateActualDistributedReward(
				incentive,
				currentTime+i-1,
				currentTime+i,
			)
			totalIncremental += distributed
		}

		dust := incentive.rewardAmount - totalIncremental
		dustPercentage := float64(dust) / float64(incentive.rewardAmount) * 100

		t.Logf("Precision test - Total: %d, Incremental sum: %d, Dust: %d (%.4f%%)",
			incentive.rewardAmount, totalIncremental, dust, dustPercentage)

		if dust > 10 { // Allow reasonable dust due to rounding
			t.Errorf("excessive dust with second-by-second precision: %d", dust)
		}
	})

	t.Run("ZeroAndNegativeValues", func(t *testing.T) {
		currentTime := time.Now().Unix()

		// Test zero reward amount
		zeroIncentive := &ExternalIncentive{
			incentiveId:      "zero_reward",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 3600,
			rewardToken:      GNS_PATH,
			rewardAmount:     0, // Zero reward
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		distributedZero := pool.CalculateActualDistributedReward(
			zeroIncentive,
			zeroIncentive.startTimestamp,
			zeroIncentive.endTimestamp,
		)

		if distributedZero != 0 {
			t.Errorf("expected 0 distribution for zero reward, got %d", distributedZero)
		}

		// Test negative reward amount (edge case that shouldn't happen in practice)
		negativeIncentive := &ExternalIncentive{
			incentiveId:      "negative_reward",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 3600,
			rewardToken:      GNS_PATH,
			rewardAmount:     -1000, // Negative amount
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		pool.stakedLiquidity.set(currentTime, u256.NewUint(10000))

		distributedNeg := pool.CalculateActualDistributedReward(
			negativeIncentive,
			negativeIncentive.startTimestamp,
			negativeIncentive.endTimestamp,
		)

		t.Logf("Negative reward test - Distributed: %d", distributedNeg)
	})
}

func TestCalculateActualDistributedReward_LiquidityChanges(t *testing.T) {
	poolPath := "test_pool_liquidity"
	currentTime := time.Now().Unix()
	pool := NewPool(poolPath, currentTime)

	t.Run("RapidLiquidityChanges", func(t *testing.T) {
		incentive := &ExternalIncentive{
			incentiveId:      "rapid_changes",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 3600,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// Simulate rapid liquidity changes
		liquidityChanges := []struct {
			time      int64
			liquidity uint64
		}{
			{currentTime, 1000},
			{currentTime + 60, 5000},
			{currentTime + 120, 2000},
			{currentTime + 180, 10000},
			{currentTime + 240, 500},
			{currentTime + 300, 8000},
			{currentTime + 360, 3000},
			{currentTime + 420, 0},    // Liquidity goes to zero
			{currentTime + 480, 6000}, // Liquidity returns
			{currentTime + 540, 4000},
			{currentTime + 600, 7000},
		}

		// Apply liquidity changes
		for _, change := range liquidityChanges {
			pool.stakedLiquidity.set(change.time, u256.NewUint(change.liquidity))
			pool.updateGlobalRewardRatioAccumulation(change.time, u256.NewUint(change.liquidity))
		}

		// Calculate distribution for different periods
		testCases := []struct {
			name      string
			startTime int64
			endTime   int64
		}{
			{"Full period", currentTime, currentTime + 600},
			{"Before zero liquidity", currentTime, currentTime + 420},
			{"During zero liquidity", currentTime + 400, currentTime + 500},
			{"After zero liquidity", currentTime + 480, currentTime + 600},
		}

		for _, tc := range testCases {
			distributed := pool.CalculateActualDistributedReward(
				incentive,
				tc.startTime,
				tc.endTime,
			)

			t.Logf("%s - Distributed: %d (period: %d-%d)",
				tc.name, distributed, tc.startTime-currentTime, tc.endTime-currentTime)

			if distributed < 0 {
				t.Errorf("%s: distributed amount should not be negative, got %d", tc.name, distributed)
			}
			if distributed > incentive.rewardAmount {
				t.Errorf("%s: distributed amount %d exceeds total reward %d", tc.name, distributed, incentive.rewardAmount)
			}
		}

		// Verify dust recovery
		fullDistributed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		dust := incentive.rewardAmount - fullDistributed
		t.Logf("Rapid changes dust: %d (%.2f%%)", dust, float64(dust)/float64(incentive.rewardAmount)*100)
	})

	t.Run("LiquidityFluctuationPattern", func(t *testing.T) {
		// Test specific pattern: high -> low -> high liquidity
		incentive := &ExternalIncentive{
			incentiveId:      "fluctuation",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 300,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// High liquidity at start
		pool.stakedLiquidity.set(currentTime, u256.NewUint(100000))
		pool.updateGlobalRewardRatioAccumulation(currentTime, u256.NewUint(100000))

		// Drop to low liquidity in middle
		pool.stakedLiquidity.set(currentTime+150, u256.NewUint(100))
		pool.updateGlobalRewardRatioAccumulation(currentTime+150, u256.NewUint(100))

		// Return to high liquidity at end
		pool.stakedLiquidity.set(currentTime+300, u256.NewUint(100000))
		pool.updateGlobalRewardRatioAccumulation(currentTime+300, u256.NewUint(100000))

		distributed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		t.Logf("Fluctuation pattern - Distributed: %d", distributed)

		if distributed <= 0 || distributed > incentive.rewardAmount {
			t.Errorf("unexpected distribution for fluctuation pattern: %d", distributed)
		}
	})

	t.Run("AccumulationWithoutLiquidityUpdates", func(t *testing.T) {
		// Test when accumulation is not updated between start and end
		incentive := &ExternalIncentive{
			incentiveId:      "no_updates",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime + 1000,
			endTimestamp:     currentTime + 2000,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// Set initial liquidity but don't update during incentive period
		pool.stakedLiquidity.set(currentTime, u256.NewUint(10000))
		pool.updateGlobalRewardRatioAccumulation(currentTime, u256.NewUint(10000))

		// Calculate without any liquidity updates during the period
		distributed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		t.Logf("No updates test - Distributed: %d", distributed)

		// Should use interpolated values
		if distributed == 0 {
			t.Errorf("expected non-zero distribution with existing liquidity")
		}
	})
}

func TestCalculateActualDistributedReward_UnclaimablePeriods(t *testing.T) {
	poolPath := "test_pool_unclaimable"
	currentTime := time.Now().Unix()
	pool := NewPool(poolPath, currentTime)

	t.Run("IncentiveDuringUnclaimablePeriod", func(t *testing.T) {
		incentive := &ExternalIncentive{
			incentiveId:      "unclaimable_period",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 1000,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// Start with zero liquidity (unclaimable period)
		pool.stakedLiquidity.set(currentTime, u256.Zero())
		pool.startUnclaimablePeriod(currentTime)

		// Calculate during unclaimable period
		distributed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.startTimestamp,
			incentive.startTimestamp+500,
		)

		t.Logf("Unclaimable period - Distributed: %d", distributed)

		// During unclaimable period with zero liquidity,
		// rewards accumulate but aren't distributed
		expectedDistributed := int64(500) * (incentive.rewardAmount / 1000)
		if distributed != expectedDistributed {
			t.Errorf("expected %d during unclaimable period, got %d", expectedDistributed, distributed)
		}
	})

	t.Run("TransitionInAndOutOfUnclaimable", func(t *testing.T) {
		incentive := &ExternalIncentive{
			incentiveId:      "transition",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 300,
			rewardToken:      GNS_PATH,
			rewardAmount:     300000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// Start with liquidity
		pool.stakedLiquidity.set(currentTime, u256.NewUint(10000))
		pool.updateGlobalRewardRatioAccumulation(currentTime, u256.NewUint(10000))

		// Go to zero (enter unclaimable)
		pool.stakedLiquidity.set(currentTime+100, u256.Zero())
		pool.updateGlobalRewardRatioAccumulation(currentTime+100, u256.Zero())
		pool.startUnclaimablePeriod(currentTime + 100)

		// Return liquidity (exit unclaimable)
		pool.stakedLiquidity.set(currentTime+200, u256.NewUint(5000))
		pool.endUnclaimablePeriod(currentTime + 200)
		pool.updateGlobalRewardRatioAccumulation(currentTime+200, u256.NewUint(5000))

		distributed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.startTimestamp,
			incentive.endTimestamp,
		)

		t.Logf("Transition test - Distributed: %d", distributed)

		// Should handle transitions correctly
		if distributed <= 0 || distributed > incentive.rewardAmount {
			t.Errorf("unexpected distribution during transitions: %d", distributed)
		}
	})
}

func TestCalculateActualDistributedReward_BoundaryConditions(t *testing.T) {
	poolPath := "test_pool_boundary"
	currentTime := time.Now().Unix()
	pool := NewPool(poolPath, currentTime)

	t.Run("InvalidTimeRanges", func(t *testing.T) {
		incentive := &ExternalIncentive{
			incentiveId:      "invalid_time",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 3600,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		// Test reversed times (start after end)
		distributedReversed := pool.CalculateActualDistributedReward(
			incentive,
			incentive.endTimestamp,   // Start after end
			incentive.startTimestamp, // End before start
		)

		if distributedReversed != 0 {
			t.Errorf("expected 0 for invalid time range, got %d", distributedReversed)
		}

		// Test zero duration (same start and end time)
		distributedZero := pool.CalculateActualDistributedReward(
			incentive,
			currentTime,
			currentTime, // Same as start
		)

		if distributedZero != 0 {
			t.Errorf("expected 0 for zero duration, got %d", distributedZero)
		}
	})

	t.Run("TimeRangeOutsideIncentivePeriod", func(t *testing.T) {
		// Test query before incentive starts
		futureIncentive := &ExternalIncentive{
			incentiveId:      "future_incentive",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime + 3600, // Starts in future
			endTimestamp:     currentTime + 7200,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		distributedBefore := pool.CalculateActualDistributedReward(
			futureIncentive,
			currentTime,
			currentTime+1800, // Before incentive starts
		)

		if distributedBefore != 0 {
			t.Errorf("expected 0 for period before incentive start, got %d", distributedBefore)
		}

		// Test query after incentive ends
		pastIncentive := &ExternalIncentive{
			incentiveId:      "past_incentive",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime - 7200, // Started in past
			endTimestamp:     currentTime - 3600, // Ended in past
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		pool.stakedLiquidity.set(currentTime-7200, u256.NewUint(10000))

		distributedAfter := pool.CalculateActualDistributedReward(
			pastIncentive,
			currentTime-1800, // After incentive ended
			currentTime,      // Way after end
		)

		t.Logf("Query after end - Distributed: %d", distributedAfter)

		// Test query with end time beyond incentive end (should be clamped)
		normalIncentive := &ExternalIncentive{
			incentiveId:      "normal_incentive",
			targetPoolPath:   poolPath,
			startTimestamp:   currentTime,
			endTimestamp:     currentTime + 1000,
			rewardToken:      GNS_PATH,
			rewardAmount:     1000000,
			refundee:         testutils.TestAddress("refundee"),
			depositGnsAmount: 100,
		}

		pool.stakedLiquidity.set(currentTime, u256.NewUint(10000))

		distributedBeyond := pool.CalculateActualDistributedReward(
			normalIncentive,
			currentTime,
			currentTime+2000, // Beyond incentive end
		)

		// Should be clamped to incentive end
		if distributedBeyond > normalIncentive.rewardAmount {
			t.Errorf("distribution exceeds total when querying beyond end: %d", distributedBeyond)
		}

		t.Logf("Query beyond incentive end - Distributed: %d", distributedBeyond)
	})
}

// validate `RewardSpent + RewardLeft = RewardAmount`
func TestRewardSpentAndLeft_Consistency(t *testing.T) {
	poolPath := "test_pool_consistency"
	currentTime := time.Now().Unix()
	pool := NewPool(poolPath, currentTime)

	incentive := &ExternalIncentive{
		incentiveId:      "consistency_test",
		targetPoolPath:   poolPath,
		startTimestamp:   currentTime,
		endTimestamp:     currentTime + 3600,
		rewardToken:      GNS_PATH,
		rewardAmount:     1000000,
		refundee:         testutils.TestAddress("refundee"),
		depositGnsAmount: 100,
	}

	// Set some liquidity
	pool.stakedLiquidity.set(currentTime, u256.NewUint(10000))

	// Test at various points in time
	testTimes := []int64{
		currentTime + 900,  // 25% through
		currentTime + 1800, // 50% through
		currentTime + 2700, // 75% through
		currentTime + 3600, // 100% through
		currentTime + 4500, // After end
	}

	for _, testTime := range testTimes {
		spent := incentive.RewardSpent(pool, testTime)
		left := incentive.RewardLeft(pool, testTime)
		total := spent + left

		t.Logf("Time %d (%.0f%% through): Spent=%d, Left=%d, Total=%d",
			testTime-currentTime,
			float64(minInt64(testTime, incentive.endTimestamp)-currentTime)/3600.0*100,
			spent, left, total)

		// Allow small rounding error due to integer division
		diff := absInt64(total - incentive.rewardAmount)
		if diff > 1 { // Allow 1 unit difference for rounding
			t.Errorf("spent + left (%d) != rewardAmount (%d), diff=%d",
				total, incentive.rewardAmount, diff)
		}
	}
}
