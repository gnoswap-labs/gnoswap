package staker

import (
	"testing"
)

func TestHandleUnstakingFee(t *testing.T) {
	tests := []struct {
		name        string
		tokenPath   string
		amount      int64
		internal    bool
		positionId  uint64
		poolPath    string
		expectedFee int64
		expectedNet int64
	}{
		{
			name:        "No fee configured",
			tokenPath:   gnsPath,
			amount:      10000,
			internal:    true,
			positionId:  1,
			poolPath:    "pool1",
			expectedFee: 0,
			expectedNet: 10000,
		},
		{
			name:        "Standard fee",
			tokenPath:   gnsPath,
			amount:      10000,
			internal:    false,
			positionId:  1,
			poolPath:    "pool1",
			expectedFee: 100,
			expectedNet: 9900,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			unstakingFee = uint64(tc.expectedFee) // Set the fee globally for the test

			netAmount, _, err := handleUnStakingFee(tc.tokenPath, tc.amount, tc.internal, tc.positionId, tc.poolPath)
			if err != nil {
				t.Errorf("Expected no error, got %v", err)
			}

			if netAmount != tc.expectedNet {
				t.Errorf("Expected netAmount %d, got %d", tc.expectedNet, netAmount)
			}
		})
	}
}

func TestSetUnstakingFee(t *testing.T) {
	tests := []struct {
		name        string
		fee         uint64
		shouldPanic bool
	}{
		{name: "Valid fee", fee: 500, shouldPanic: false},
		{name: "Excessive fee", fee: 10001, shouldPanic: true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil && !tc.shouldPanic {
					t.Errorf("Unexpected panic for fee %d: %v", tc.fee, r)
				}
			}()

			setUnStakingFee(tc.fee)

			if !tc.shouldPanic {
				if unstakingFee != tc.fee {
					t.Errorf("Expected fee %d, got %d", tc.fee, unstakingFee)
				}
			}
		})
	}
}
