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
			name:              "overflow - large values",
			depositTime:       math.MaxInt64 / 2,
			claimableDuration: math.MaxInt64/2 + 1,
			shouldOverflow:    true,
			description:       "Half MaxInt64 + Half MaxInt64 + 1 should overflow",
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

// TestRewardManager_collectReward tests overflow in claimed amount update
func TestRewardManager_collectReward(t *testing.T) {
	tests := []struct {
		name             string
		initialClaimed   int64
		claimableReward  int64
		shouldOverflow   bool
		description      string
	}{
		{
			name:            "normal - no overflow",
			initialClaimed:  1000,
			claimableReward: 500,
			shouldOverflow:  false,
			description:     "Normal accumulation without overflow",
		},
		{
			name:            "boundary - MaxInt64 with 0 reward",
			initialClaimed:  math.MaxInt64,
			claimableReward: 0,
			shouldOverflow:  false,
			description:     "MaxInt64 + 0 should not overflow",
		},
		{
			name:            "overflow - MaxInt64 with 1 reward",
			initialClaimed:  math.MaxInt64,
			claimableReward: 1,
			shouldOverflow:  true,
			description:     "MaxInt64 + 1 should overflow",
		},
		{
			name:            "overflow - near MaxInt64",
			initialClaimed:  math.MaxInt64 - 100,
			claimableReward: 200,
			shouldOverflow:  true,
			description:     "(MaxInt64 - 100) + 200 should overflow",
		},
		{
			name:            "boundary - exactly MaxInt64",
			initialClaimed:  math.MaxInt64 - 1000,
			claimableReward: 1000,
			shouldOverflow:  false,
			description:     "Exactly reaching MaxInt64 should not overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			currentTime := time.Now().Unix()
			distributeStart := currentTime - 1000
			distributeEnd := currentTime + 1000

			manager := NewRewardManager(
				10000000,
				distributeStart,
				distributeEnd,
				100,
				currentTime,
			)

			deposit := NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				currentTime-500,
				distributeEnd,
			)

			rewardState := manager.addRewardStateByDeposit(deposit)
			rewardState.setClaimedAmount(tt.initialClaimed)

			if tt.claimableReward > 0 {
				// accumulatedRewardPerDepositX128 needs to be set so that
				// (accumulated - priceDebt) * depositAmount / 2^128 = claimableReward
				targetReward := tt.claimableReward + tt.initialClaimed

				// Calculate required accumulated per deposit
				depositAmount := deposit.DepositAmount()
				requiredAccumX128 := u256.NewUintFromInt64(targetReward)
				requiredAccumX128 = u256.Zero().Lsh(requiredAccumX128, 128)
				requiredAccumX128 = u256.Zero().Div(requiredAccumX128, u256.NewUintFromInt64(depositAmount))

				manager.accumulatedRewardPerDepositX128 = requiredAccumX128
			}

			// when
			resultAmount, _ := manager.collectReward(deposit.ID(), currentTime)

			// then
			if tt.shouldOverflow {
				newClaimedAmount := rewardState.ClaimedAmount()
				expected := tt.initialClaimed + tt.claimableReward
				if expected < 0 {
					uassert.True(t, newClaimedAmount < tt.initialClaimed || newClaimedAmount < 0,
						"Overflow should result in wraparound")
				}
			} else {
				if tt.claimableReward > 0 {
					uassert.Equal(t, resultAmount, tt.claimableReward,
						"Should collect exact claimable reward")
				}
			}
		})
	}
}

// TestRewardManager_collectReward_TotalClaimedAmountOverflow tests overflow in total claimed amount
func TestRewardManager_collectReward_TotalClaimedAmountOverflow(t *testing.T) {
	tests := []struct {
		name              string
		initialTotal      int64
		claimableReward   int64
		shouldOverflow    bool
		description       string
	}{
		{
			name:            "normal - no overflow",
			initialTotal:    1000,
			claimableReward: 500,
			shouldOverflow:  false,
			description:     "Normal accumulation without overflow",
		},
		{
			name:            "boundary - MaxInt64 with 0 reward",
			initialTotal:    math.MaxInt64,
			claimableReward: 0,
			shouldOverflow:  false,
			description:     "MaxInt64 + 0 should not overflow",
		},
		{
			name:            "overflow - MaxInt64 with 1 reward",
			initialTotal:    math.MaxInt64,
			claimableReward: 1,
			shouldOverflow:  true,
			description:     "MaxInt64 + 1 should overflow",
		},
		{
			name:            "overflow - near MaxInt64",
			initialTotal:    math.MaxInt64 - 50,
			claimableReward: 100,
			shouldOverflow:  true,
			description:     "(MaxInt64 - 50) + 100 should overflow",
		},
		{
			name:            "boundary - exactly MaxInt64",
			initialTotal:    math.MaxInt64 - 500,
			claimableReward: 500,
			shouldOverflow:  false,
			description:     "Exactly reaching MaxInt64 should not overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			currentTime := time.Now().Unix()
			distributeStart := currentTime - 1000
			distributeEnd := currentTime + 1000

			manager := NewRewardManager(
				10000000,
				distributeStart,
				distributeEnd,
				100,
				currentTime,
			)

			// Set initial total claimed amount
			manager.totalClaimedAmount = tt.initialTotal

			deposit := NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				currentTime-500,
				distributeEnd,
			)

			// Add reward state
			_ = manager.addRewardStateByDeposit(deposit)

			// Set up rewards to get desired claimableReward
			if tt.claimableReward > 0 {
				depositAmount := deposit.DepositAmount()
				requiredAccumX128 := u256.NewUintFromInt64(tt.claimableReward)
				requiredAccumX128 = u256.Zero().Lsh(requiredAccumX128, 128)
				requiredAccumX128 = u256.Zero().Div(requiredAccumX128, u256.NewUintFromInt64(depositAmount))

				manager.accumulatedRewardPerDepositX128 = requiredAccumX128
			}

			initialTotal := manager.totalClaimedAmount

			// when
			_, _ = manager.collectReward(deposit.ID(), currentTime)

			// then
			newTotal := manager.totalClaimedAmount

			if tt.shouldOverflow {
				// If overflow occurred, totalClaimedAmount would wrap around
				expected := initialTotal + tt.claimableReward
				if expected < 0 {
					// Overflow occurred
					uassert.True(t, newTotal < initialTotal || newTotal < 0,
						"Overflow should result in wraparound to negative or smaller value")
				}
			} else {
				// No overflow - total should increase correctly
				if tt.claimableReward > 0 {
					uassert.Equal(t, newTotal, initialTotal+tt.claimableReward,
						"Total claimed should increase by claimable reward")
				}
			}
		})
	}
}
