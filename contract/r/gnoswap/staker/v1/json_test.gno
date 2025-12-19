package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	sr "gno.land/r/gnoswap/staker"
)

// TestNewApiStake_StakeDurationCalculation tests that stakeDuration is correctly calculated
// using timestamps, not block heights. This is a regression test for a bug where
// runtime.ChainHeight() was incorrectly compared with deposit.StakeTime().
func TestNewApiStake_StakeDurationCalculation(t *testing.T) {
	tests := []struct {
		name              string
		stakeTime         int64
		waitSeconds       int64
		expectedDuration  uint64
	}{
		{
			name:             "stake duration after 100 seconds",
			stakeTime:        time.Now().Unix() - 100,
			waitSeconds:      0,
			expectedDuration: 100,
		},
		{
			name:             "stake duration after 3600 seconds (1 hour)",
			stakeTime:        time.Now().Unix() - 3600,
			waitSeconds:      0,
			expectedDuration: 3600,
		},
		{
			name:             "stake duration is zero when staked just now",
			stakeTime:        time.Now().Unix(),
			waitSeconds:      0,
			expectedDuration: 0,
		},
		{
			name:             "stake duration is zero when stake time is in future",
			stakeTime:        time.Now().Unix() + 100,
			waitSeconds:      0,
			expectedDuration: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deposit := &sr.Deposit{}
			deposit.SetStakeTime(tt.stakeTime)
			deposit.SetOwner("g1test")
			deposit.SetTargetPoolPath("gno.land/r/test/pool")

			apiStake := newApiStake(1, deposit)

			// Allow 1 second tolerance for test execution time
			if apiStake.StakeDuration > 0 {
				diff := int64(apiStake.StakeDuration) - int64(tt.expectedDuration)
				if diff < 0 {
					diff = -diff
				}
				uassert.True(t, diff <= 1, "stake duration should be within 1 second tolerance")
			} else {
				uassert.Equal(t, tt.expectedDuration, apiStake.StakeDuration)
			}

			// Verify other fields are set correctly
			uassert.Equal(t, uint64(1), apiStake.PositionId)
			uassert.Equal(t, tt.stakeTime, apiStake.StakeTimestamp)
			uassert.Equal(t, tt.stakeTime, apiStake.StakeTime)
		})
	}
}
