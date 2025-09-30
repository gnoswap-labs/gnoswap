package launchpad

import (
	"testing"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

// TestTierDurationConsistency verifies tier duration consistency across multiple scenarios
func TestTierDurationConsistency(t *testing.T) {
	tests := []struct {
		name                   string
		tierType               int64 // 30, 90, or 180
		daysBeforeFirstDeposit int64 // How many days to wait before first deposit
		expectedDurationDays   int64 // Expected tier duration in days
		depositCount           int   // Number of deposits to make
	}{
		{
			name:                   "tier_30_immediate_deposit",
			tierType:               30,
			daysBeforeFirstDeposit: 0,
			expectedDurationDays:   30,
			depositCount:           3,
		},
		{
			name:                   "tier_30_deposit_after_5_days",
			tierType:               30,
			daysBeforeFirstDeposit: 5,
			expectedDurationDays:   30,
			depositCount:           2,
		},
		{
			name:                   "tier_30_deposit_after_15_days",
			tierType:               30,
			daysBeforeFirstDeposit: 15,
			expectedDurationDays:   30,
			depositCount:           1,
		},
		{
			name:                   "tier_30_very_late_deposit",
			tierType:               30,
			daysBeforeFirstDeposit: 25,
			expectedDurationDays:   30,
			depositCount:           1,
		},
		{
			name:                   "tier_90_immediate_deposit",
			tierType:               90,
			daysBeforeFirstDeposit: 0,
			expectedDurationDays:   90,
			depositCount:           3,
		},
		{
			name:                   "tier_90_deposit_after_30_days",
			tierType:               90,
			daysBeforeFirstDeposit: 30,
			expectedDurationDays:   90,
			depositCount:           2,
		},
		{
			name:                   "tier_180_immediate_deposit",
			tierType:               180,
			daysBeforeFirstDeposit: 0,
			expectedDurationDays:   180,
			depositCount:           3,
		},
		{
			name:                   "tier_180_deposit_after_60_days",
			tierType:               180,
			daysBeforeFirstDeposit: 60,
			expectedDurationDays:   180,
			depositCount:           2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposits = avl.NewTree()
			depositCounter = NewCounter()
			projects = avl.NewTree()
			projectTierRewardManagers = avl.NewTree()

			ctx := testing.GetContext()
			ctx.Height = 100
			ctx.Time = time.Unix(100, 0)
			testing.SetContext(ctx)

			currentTime := ctx.Time.Unix()
			currentHeight := ctx.Height

			// Set tier ratios based on tier type
			tier30Ratio := int64(0)
			tier90Ratio := int64(0)
			tier180Ratio := int64(0)

			switch tt.tierType {
			case 30:
				tier30Ratio = 100
			case 90:
				tier90Ratio = 100
			case 180:
				tier180Ratio = 100
			}

			project, _ := createProject(
				&createProjectParams{
					name:          "Test Project " + tt.name,
					tokenPath:     "gno.land/r/onbloc/obl",
					depositAmount: 10000000,
					tier30Ratio:   tier30Ratio,
					tier90Ratio:   tier90Ratio,
					tier180Ratio:  tier180Ratio,
					recipient:     testutils.TestAddress("project"),
					startTime:     currentTime,
					currentTime:   currentTime,
					currentHeight: currentHeight,
				},
			)
			projects.Set(project.ID(), project)
			tier, _ := project.getTier(tt.tierType)

			initialStartTime := tier.StartTime()
			initialEndTime := tier.EndTime()
			initialDistributePerSecond := tier.DistributeAmountPerSecondX128().ToString()

			// calculate expected duration in blocks
			expectedDurationBlocks := tt.expectedDurationDays * 24 * 60 * 60

			// verify initial duration
			actualInitialDuration := initialEndTime - initialStartTime
			uassert.Equal(t, expectedDurationBlocks, actualInitialDuration,
				"Initial tier duration mismatch")

			// wait before first deposit if needed
			if tt.daysBeforeFirstDeposit > 0 {
				blocksToWait := tt.daysBeforeFirstDeposit * 24 * 60 * 60
				ctx.Time = time.Unix(currentTime+blocksToWait, 0)
				testing.SetContext(ctx)
			}

			// Make deposits
			for i := 0; i < tt.depositCount; i++ {
				user := testutils.TestAddress("user" + formatInt(int64(i)))
				testing.SetOriginCaller(user)

				_, _, isFirstDeposit, _, _ := depositGns(project.ID(), tt.tierType, 1000000, user)

				if i == 0 {
					uassert.True(t, isFirstDeposit, "First deposit should be marked as such")
				} else {
					uassert.False(t, isFirstDeposit, "Subsequent deposits should not be marked as first")
				}
			}

			// Get tier state after all deposits
			tierAfterDeposits, _ := project.getTier(tt.tierType)

			// Verify nothing changed
			uassert.Equal(t, initialStartTime, tierAfterDeposits.StartTime(),
				"%s: Start height should not change", tt.name)
			uassert.Equal(t, initialEndTime, tierAfterDeposits.EndTime(),
				"%s: End height should not change", tt.name)
			uassert.Equal(t, initialDistributePerSecond, tierAfterDeposits.DistributeAmountPerSecondX128().ToString(),
				"%s: Distribute per second should not change", tt.name)

			// Verify duration remains consistent
			finalDuration := tierAfterDeposits.EndTime() - tierAfterDeposits.StartTime()
			uassert.Equal(t, expectedDurationBlocks, finalDuration,
				"Duration should remain consistent")
		})
	}
}

// calculateEndTimeByTierType calculates the end time based on tier type
func calculateEndTimeByTierType(tierType int64, startTime int64) int64 {
	// Calculate end time based on tier duration
	endTime := startTime + projectTierDurationTimes[tierType]

	return endTime
}

// TestTierDuration_TimestampBasedCalculation tests that tier duration calculations are time-based
func TestTierDuration_TimestampBasedCalculation(t *testing.T) {
	tests := []struct {
		name                 string
		tierType             int64
		startTime            int64
		averageBlockTimeMs   int64
		expectedDurationDays int64
		description          string
	}{
		{
			name:                 "30 day tier standard",
			tierType:             30,
			startTime:            1000000,
			averageBlockTimeMs:   5000, // 5 seconds per block
			expectedDurationDays: 30,
			description:          "30 day tier should always be 30 days regardless of block time",
		},
		{
			name:                 "30 day tier with fast blocks",
			tierType:             30,
			startTime:            1000000,
			averageBlockTimeMs:   1000, // 1 second per block
			expectedDurationDays: 30,
			description:          "30 day tier should still be 30 days with fast blocks",
		},
		{
			name:                 "30 day tier with slow blocks",
			tierType:             30,
			startTime:            1000000,
			averageBlockTimeMs:   20000, // 20 seconds per block
			expectedDurationDays: 30,
			description:          "30 day tier should still be 30 days with slow blocks",
		},
		{
			name:                 "90 day tier",
			tierType:             90,
			startTime:            1000000,
			averageBlockTimeMs:   5000,
			expectedDurationDays: 90,
			description:          "90 day tier should be 90 days",
		},
		{
			name:                 "180 day tier",
			tierType:             180,
			startTime:            1000000,
			averageBlockTimeMs:   5000,
			expectedDurationDays: 180,
			description:          "180 day tier should be 180 days",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Calculate end time info
			endTimeInfo := calculateEndTimeByTierType(
				tt.tierType,
				tt.startTime,
			)

			// Calculate actual duration in seconds
			actualDurationSeconds := endTimeInfo - tt.startTime
			actualDurationDays := actualDurationSeconds / 86400 // seconds per day

			// Verify the duration matches expected days
			uassert.Equal(t, tt.expectedDurationDays, actualDurationDays, tt.description)
		})
	}
}
