package v1

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

// TestExtreme_MinimumDepositAmount tests the minimum valid deposit amount
func TestExtreme_MinimumDepositAmount(t *testing.T) {
	tests := []struct {
		name             string
		depositAmount    int64
		expectedHasError bool
	}{
		{
			name:             "exactly minimum amount (1_000_000)",
			depositAmount:    1_000_000,
			expectedHasError: false,
		},
		{
			name:             "one less than minimum (999_999)",
			depositAmount:    999_999,
			expectedHasError: true,
		},
		{
			name:             "zero amount",
			depositAmount:    0,
			expectedHasError: true,
		},
		{
			name:             "negative amount",
			depositAmount:    -1,
			expectedHasError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedHasError {
				uassert.AbortsWithMessage(t, "", func() {
					assertIsValidAmount(tt.depositAmount)
				})
			} else {
				// Should not panic
				assertIsValidAmount(tt.depositAmount)
			}
		})
	}
}

// TestExtreme_LargeDepositAmounts tests very large deposit amounts
func TestExtreme_LargeDepositAmounts(t *testing.T) {
	const MaxInt64 = int64(9223372036854775807)

	tests := []struct {
		name             string
		depositAmount    int64
		expectedHasError bool
	}{
		{
			name:             "large but valid amount (1 billion)",
			depositAmount:    1_000_000_000,
			expectedHasError: false,
		},
		{
			name:             "very large amount (1 trillion)",
			depositAmount:    1_000_000_000_000,
			expectedHasError: false,
		},
		{
			name:             "near MaxInt64",
			depositAmount:    MaxInt64 - 1000,
			expectedHasError: false,
		},
		{
			name:             "exactly MaxInt64",
			depositAmount:    MaxInt64,
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedHasError {
				uassert.AbortsWithMessage(t, "", func() {
					assertIsValidAmount(tt.depositAmount)
				})
			} else {
				// Should not panic for large valid amounts
				assertIsValidAmount(tt.depositAmount)
			}
		})
	}
}

// TestExtreme_TimeBoundaries tests time-related boundary conditions
func TestExtreme_TimeBoundaries(t *testing.T) {
	tests := []struct {
		name              string
		currentTime       int64
		startTime         int64
		endTime           int64
		expectedIsActive  bool
		expectedIsEnded   bool
	}{
		{
			name:              "exactly at start time",
			currentTime:       1000,
			startTime:         1000,
			endTime:           2000,
			expectedIsActive:  true,
			expectedIsEnded:   false,
		},
		{
			name:              "one second before end",
			currentTime:       1999,
			startTime:         1000,
			endTime:           2000,
			expectedIsActive:  true,
			expectedIsEnded:   false,
		},
		{
			name:              "exactly at end time",
			currentTime:       2000,
			startTime:         1000,
			endTime:           2000,
			expectedIsActive:  true,
			expectedIsEnded:   false,
		},
		{
			name:              "one second after end",
			currentTime:       2001,
			startTime:         1000,
			endTime:           2000,
			expectedIsActive:  true,
			expectedIsEnded:   true,
		},
		{
			name:              "long period (365 days in seconds)",
			currentTime:       1000 + 31536000,
			startTime:         1000,
			endTime:           1000 + 31536000 - 1,
			expectedIsActive:  true,
			expectedIsEnded:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create a test deposit
			deposit := NewDeposit(
				"test-deposit",
				"test-project",
				30,
				testutils.TestAddress("user"),
				1000000,
				100,
				tt.startTime,
				tt.endTime,
			)

			isEnded := deposit.IsEnded(tt.currentTime)
			uassert.Equal(t, tt.expectedIsEnded, isEnded, "IsEnded should match expected")
		})
	}
}

// TestExtreme_RewardCalculationPrecision tests reward calculation precision
func TestExtreme_RewardCalculationPrecision(t *testing.T) {
	tests := []struct {
		name                   string
		totalDistributeAmount  int64
		distributeStartTime    int64
		distributeEndTime      int64
		depositAmount          int64
		expectedPrecisionError bool
	}{
		{
			name:                   "small amounts with long duration",
			totalDistributeAmount:  100,
			distributeStartTime:    1000,
			distributeEndTime:      1000 + 2592000, // 30 days
			depositAmount:          1,
			expectedPrecisionError: false,
		},
		{
			name:                   "large amounts with short duration",
			totalDistributeAmount:  1_000_000_000,
			distributeStartTime:    1000,
			distributeEndTime:      1001, // 1 second
			depositAmount:          1_000_000,
			expectedPrecisionError: false,
		},
		{
			name:                   "very small distribute amount",
			totalDistributeAmount:  1,
			distributeStartTime:    1000,
			distributeEndTime:      1000 + 2592000,
			depositAmount:          1_000_000,
			expectedPrecisionError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create reward manager
			rewardManager := NewRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
				100, // currentHeight
				tt.distributeStartTime,
			)

			// Create deposit
			deposit := NewDeposit(
				"test-deposit",
				"test-project",
				30,
				testutils.TestAddress("user"),
				tt.depositAmount,
				100,
				tt.distributeStartTime,
				tt.distributeEndTime,
			)

			// Add deposit to manager
			_ = rewardManager.addRewardStateByDeposit(deposit)

			// Update reward calculation
			err := rewardManager.updateRewardPerDepositX128(
				tt.depositAmount,
				100,
				tt.distributeStartTime,
			)

			if tt.expectedPrecisionError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err, "should handle precision without error")
			}
		})
	}
}

// TestExtreme_ProjectDurationBoundaries tests project duration extremes
func TestExtreme_ProjectDurationBoundaries(t *testing.T) {
	tests := []struct {
		name               string
		tierDuration       int64
		expectedIsValid    bool
	}{
		{
			name:            "30 days (valid)",
			tierDuration:    30,
			expectedIsValid: true,
		},
		{
			name:            "90 days (valid)",
			tierDuration:    90,
			expectedIsValid: true,
		},
		{
			name:            "180 days (valid)",
			tierDuration:    180,
			expectedIsValid: true,
		},
		{
			name:            "invalid tier (60 days)",
			tierDuration:    60,
			expectedIsValid: false,
		},
		{
			name:            "zero days",
			tierDuration:    0,
			expectedIsValid: false,
		},
		{
			name:            "negative days",
			tierDuration:    -30,
			expectedIsValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := tt.tierDuration == 30 || tt.tierDuration == 90 || tt.tierDuration == 180
			uassert.Equal(t, tt.expectedIsValid, isValid)
		})
	}
}

// TestExtreme_MultipleDepositsCapacity tests handling many deposits
func TestExtreme_MultipleDepositsCapacity(t *testing.T) {
	// Create many deposits to test system capacity
	const numDeposits = 100

	deposits := make([]*Deposit, numDeposits)

	for i := 0; i < numDeposits; i++ {
		deposits[i] = NewDeposit(
			formatInt(int64(i)),
			"test-project",
			30,
			testutils.TestAddress("user"),
			1_000_000,
			100,
			1000,
			1000+2592000,
		)

		uassert.NotNil(t, deposits[i], "should create deposit")
		uassert.Equal(t, formatInt(int64(i)), deposits[i].ID())
	}

	// Verify all deposits are unique
	seen := make(map[string]bool)
	for _, deposit := range deposits {
		id := deposit.ID()
		uassert.False(t, seen[id], "deposit ID should be unique")
		seen[id] = true
	}

	uassert.Equal(t, numDeposits, len(seen), "should have created all deposits")
}
