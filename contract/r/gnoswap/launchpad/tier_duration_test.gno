package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
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

			currentTime := time.Now().Unix()
			currentHeight := int64(100)
			testing.SetHeight(currentHeight)

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
					name:               "Test Project " + tt.name,
					tokenPath:          "gno.land/r/onbloc/obl",
					depositAmount:      10000000,
					tier30Ratio:        tier30Ratio,
					tier90Ratio:        tier90Ratio,
					tier180Ratio:       tier180Ratio,
					averageBlockTimeMs: 2000, // 2 seconds per block
					recipient:          testutils.TestAddress("project"),
					startTime:          currentTime,
					currentTime:        currentTime,
					currentHeight:      currentHeight,
				},
			)
			projects.Set(project.ID(), project)
			tier, _ := project.getTier(tt.tierType)

			initialStartHeight := tier.StartHeight()
			initialEndHeight := tier.EndHeight()
			initialDistributePerBlock := tier.DistributeAmountPerBlockX128().ToString()

			// calculate expected duration in blocks
			expectedDurationBlocks := tt.expectedDurationDays * 24 * 60 * 60 / 2

			// verify initial duration
			actualInitialDuration := initialEndHeight - initialStartHeight
			uassert.Equal(t, expectedDurationBlocks, actualInitialDuration,
				"Initial tier duration mismatch")

			// wait before first deposit if needed
			if tt.daysBeforeFirstDeposit > 0 {
				blocksToWait := tt.daysBeforeFirstDeposit * 24 * 60 * 60 / 2
				testing.SetHeight(currentHeight + blocksToWait)
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

				// Wait 1 day between deposits
				if i < tt.depositCount-1 {
					testing.SetHeight(std.ChainHeight() + 43200) // 1 day
				}
			}

			// Get tier state after all deposits
			tierAfterDeposits, _ := project.getTier(tt.tierType)

			// Verify nothing changed
			uassert.Equal(t, initialStartHeight, tierAfterDeposits.StartHeight(),
				"%s: Start height should not change", tt.name)
			uassert.Equal(t, initialEndHeight, tierAfterDeposits.EndHeight(),
				"%s: End height should not change", tt.name)
			uassert.Equal(t, initialDistributePerBlock, tierAfterDeposits.DistributeAmountPerBlockX128().ToString(),
				"%s: Distribute per block should not change", tt.name)

			// Verify duration remains consistent
			finalDuration := tierAfterDeposits.EndHeight() - tierAfterDeposits.StartHeight()
			uassert.Equal(t, expectedDurationBlocks, finalDuration,
				"Duration should remain consistent")
		})
	}
}
