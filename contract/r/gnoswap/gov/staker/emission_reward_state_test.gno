package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

// TestNewEmissionRewardState tests creating a new emission reward state
func TestNewEmissionRewardState(t *testing.T) {
	tests := []struct {
		name                            string
		accumulatedRewardX128PerStake   string
		expectedAccumulatedRewardAmount int64
		expectedStakedAmount            int64
	}{
		{
			name:                            "Create with zero accumulated reward",
			accumulatedRewardX128PerStake:   "0",
			expectedAccumulatedRewardAmount: 0,
			expectedStakedAmount:            0,
		},
		{
			name:                            "Create with non-zero accumulated reward",
			accumulatedRewardX128PerStake:   "1000",
			expectedAccumulatedRewardAmount: 0,
			expectedStakedAmount:            0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			state := NewEmissionRewardState(tc.accumulatedRewardX128PerStake)

			// then
			uassert.NotNil(t, state)
			uassert.Equal(t, state.GetRewardDebtX128(), tc.accumulatedRewardX128PerStake)
			uassert.Equal(t, state.GetAccumulatedRewardAmount(), tc.expectedAccumulatedRewardAmount)
			uassert.Equal(t, state.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, state.GetClaimedRewardAmount(), int64(0))
			uassert.Equal(t, state.GetClaimedTimestamp(), int64(0))
			uassert.Equal(t, state.GetStakedAmount(), tc.expectedStakedAmount)
		})
	}
}

// TestEmissionRewardState_Setters tests all setter methods
func TestEmissionRewardState_Setters(t *testing.T) {
	tests := []struct {
		name                     string
		newRewardDebtX128        string
		newAccumulatedAmount     int64
		newAccumulatedTimestamp  int64
		newClaimedAmount         int64
		newClaimedTimestamp      int64
		newStakedAmount          int64
	}{
		{
			name:                    "Set all values to non-zero",
			newRewardDebtX128:       "5000",
			newAccumulatedAmount:    1000,
			newAccumulatedTimestamp: 1000000,
			newClaimedAmount:        500,
			newClaimedTimestamp:     2000000,
			newStakedAmount:         10000,
		},
		{
			name:                    "Set all values to zero",
			newRewardDebtX128:       "0",
			newAccumulatedAmount:    0,
			newAccumulatedTimestamp: 0,
			newClaimedAmount:        0,
			newClaimedTimestamp:     0,
			newStakedAmount:         0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := NewEmissionRewardState("100")

			// when
			state.SetRewardDebtX128(tc.newRewardDebtX128)
			state.SetAccumulatedRewardAmount(tc.newAccumulatedAmount)
			state.SetAccumulatedTimestamp(tc.newAccumulatedTimestamp)
			state.SetClaimedRewardAmount(tc.newClaimedAmount)
			state.SetClaimedTimestamp(tc.newClaimedTimestamp)
			state.SetStakedAmount(tc.newStakedAmount)

			// then
			uassert.Equal(t, state.GetRewardDebtX128(), tc.newRewardDebtX128)
			uassert.Equal(t, state.GetAccumulatedRewardAmount(), tc.newAccumulatedAmount)
			uassert.Equal(t, state.GetAccumulatedTimestamp(), tc.newAccumulatedTimestamp)
			uassert.Equal(t, state.GetClaimedRewardAmount(), tc.newClaimedAmount)
			uassert.Equal(t, state.GetClaimedTimestamp(), tc.newClaimedTimestamp)
			uassert.Equal(t, state.GetStakedAmount(), tc.newStakedAmount)
		})
	}
}

// TestEmissionRewardState_Getters tests all getter methods
func TestEmissionRewardState_Getters(t *testing.T) {
	tests := []struct {
		name                  string
		initialRewardDebtX128 string
	}{
		{
			name:                  "Get initial values",
			initialRewardDebtX128: "12345",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := NewEmissionRewardState(tc.initialRewardDebtX128)

			// when & then
			uassert.Equal(t, state.GetRewardDebtX128(), tc.initialRewardDebtX128)
			uassert.Equal(t, state.GetAccumulatedRewardAmount(), int64(0))
			uassert.Equal(t, state.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, state.GetClaimedRewardAmount(), int64(0))
			uassert.Equal(t, state.GetClaimedTimestamp(), int64(0))
			uassert.Equal(t, state.GetStakedAmount(), int64(0))
		})
	}
}

// TestEmissionRewardState_StringImmutability tests that string values are immutable
func TestEmissionRewardState_StringImmutability(t *testing.T) {
	tests := []struct {
		name                  string
		initialRewardDebtX128 string
		modifiedValue         string
	}{
		{
			name:                  "Modifying original should not affect state",
			initialRewardDebtX128: "1000",
			modifiedValue:         "9999",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			original := tc.initialRewardDebtX128

			// when
			state := NewEmissionRewardState(original)
			original = tc.modifiedValue // Try to modify original (string is immutable, this creates a new variable)

			// then - state should still have the original value
			uassert.Equal(t, state.GetRewardDebtX128(), tc.initialRewardDebtX128)
			uassert.NotEqual(t, state.GetRewardDebtX128(), tc.modifiedValue)
		})
	}
}
