package v1

import (
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestRewardManager_addRewardStateByDeposit tests overflow in claimableTime calculation
func TestRewardManager_addRewardStateByDeposit(t *testing.T) {
	tests := []struct {
		name              string
		depositTime       int64
		claimableDuration int64
		shouldOverflow    bool
		description       string
	}{
		{
			name:              "normal - no overflow",
			depositTime:       1000,
			claimableDuration: 500,
			shouldOverflow:    false,
			description:       "Normal addition without overflow",
		},
		{
			name:              "boundary - MaxInt64 depositTime with duration 0",
			depositTime:       math.MaxInt64,
			claimableDuration: 0,
			shouldOverflow:    false,
			description:       "MaxInt64 + 0 should not overflow",
		},
		{
			name:              "overflow - MaxInt64 depositTime with duration 1",
			depositTime:       math.MaxInt64,
			claimableDuration: 1,
			shouldOverflow:    true,
			description:       "MaxInt64 + 1 should overflow",
		},
		{
			name:              "overflow - near MaxInt64",
			depositTime:       math.MaxInt64 - 100,
			claimableDuration: 200,
			shouldOverflow:    true,
			description:       "(MaxInt64 - 100) + 200 should overflow",
		},
		{
			name:              "boundary - exactly MaxInt64",
			depositTime:       math.MaxInt64 - 1000,
			claimableDuration: 1000,
			shouldOverflow:    false,
			description:       "Exactly reaching MaxInt64 should not overflow",
		},
		{
			name:              "boundary - large values exactly MaxInt64",
			depositTime:       math.MaxInt64 / 2,
			claimableDuration: math.MaxInt64/2 + 1,
			shouldOverflow:    false,
			description:       "Half MaxInt64 + Half MaxInt64 + 1 equals MaxInt64 (no overflow)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := NewRewardManager(
				1000000,
				time.Now().Unix(),
				time.Now().Unix()+1000,
				100,
				time.Now().Unix(),
			)
			manager.rewardClaimableDuration = tt.claimableDuration

			deposit := NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				tt.depositTime,
				tt.depositTime+1000,
			)

			// when & then
			if tt.shouldOverflow {
				rewardState := manager.addRewardStateByDeposit(deposit)
				claimableTime := rewardState.ClaimableTime()

				uassert.True(t, claimableTime < 0 || claimableTime < tt.depositTime,
					"Overflow should result in negative or smaller value")
			} else {
				rewardState := manager.addRewardStateByDeposit(deposit)
				claimableTime := rewardState.ClaimableTime()

				uassert.True(t, claimableTime >= tt.depositTime,
					"No overflow - claimableTime should be >= depositTime")
			}
		})
	}
}

func TestRewardManager_updateDistributeAmountPerSecondX128(t *testing.T) {
	tests := []struct {
		name                string
		totalDistribute     int64
		distributeStart     int64
		distributeEnd       int64
		expectedUpdated     bool
		checkAmountPerSec   bool
	}{
		{
			name:            "normal - calculate correct amount per second",
			totalDistribute: 1000000,
			distributeStart: 100,
			distributeEnd:   200,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "edge case - distributeStart equals distributeEnd (timeDuration = 0)",
			totalDistribute: 1000000,
			distributeStart: 100,
			distributeEnd:   100,
			expectedUpdated: false,
		},
		{
			name:            "edge case - distributeStart greater than distributeEnd (negative duration)",
			totalDistribute: 1000000,
			distributeStart: 200,
			distributeEnd:   100,
			expectedUpdated: false,
		},
		{
			name:            "edge case - totalDistributeAmount is zero",
			totalDistribute: 0,
			distributeStart: 100,
			distributeEnd:   200,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "boundary - very small timeDuration (1 second)",
			totalDistribute: 1000000,
			distributeStart: 100,
			distributeEnd:   101,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "boundary - very large timeDuration",
			totalDistribute: 1000000,
			distributeStart: 0,
			distributeEnd:   31536000, // 1 year in seconds
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "boundary - large totalDistribute",
			totalDistribute: 9223372036854775807, // MaxInt64
			distributeStart: 100,
			distributeEnd:   200,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := &RewardManager{
				distributeAmountPerSecondX128: u256.Zero(),
				distributeStartTime:           0,
				distributeEndTime:             0,
			}
			initialAmountPerSec := manager.distributeAmountPerSecondX128.Clone()

			// when
			manager.updateDistributeAmountPerSecondX128(
				tt.totalDistribute,
				tt.distributeStart,
				tt.distributeEnd,
			)

			// then
			if tt.expectedUpdated {
				if tt.distributeEnd <= tt.distributeStart {
					// Should not update if duration invalid
					uassert.True(t, manager.distributeAmountPerSecondX128.Eq(initialAmountPerSec),
						"Should not update with invalid duration")
				} else {
					// Verify times were set
					uassert.Equal(t, manager.distributeStartTime, tt.distributeStart)
					uassert.Equal(t, manager.distributeEndTime, tt.distributeEnd)

					if tt.checkAmountPerSec {
						// Verify amountPerSecond is not zero (unless totalDistribute is zero)
						if tt.totalDistribute == 0 {
							uassert.True(t, manager.distributeAmountPerSecondX128.IsZero(),
								"Amount per second should be zero when total is zero")
						} else {
							uassert.False(t, manager.distributeAmountPerSecondX128.IsZero(),
								"Amount per second should not be zero")
						}
					}
				}
			} else {
				// Should not update
				uassert.True(t, manager.distributeAmountPerSecondX128.Eq(initialAmountPerSec),
					"Should not update amount per second")
			}
		})
	}
}
