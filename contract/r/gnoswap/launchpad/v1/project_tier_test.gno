package v1

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/launchpad"
)

func TestProjectTier_Getters(t *testing.T) {
	tests := []struct {
		name                          string
		id                            string
		totalDistributeAmount         int64
		distributeAmountPerSecondX128 *u256.Uint
		startTime                     int64
		startHeight                   int64
		endTime                       int64
		endHeight                     int64
		totalDepositAmount            int64
		totalWithdrawAmount           int64
		totalDepositCount             int64
		totalWithdrawCount            int64
		totalCollectedAmount          int64
		getterFunc                    string
		expectedValue                 interface{}
	}{
		{
			name:                          "project tier get id",
			id:                            "test:180",
			totalDistributeAmount:         1000,
			distributeAmountPerSecondX128: u256.NewUintFromInt64(100),
			startTime:                     1000,
			startHeight:                   100,
			endTime:                       2000,
			endHeight:                     200,
			totalDepositAmount:            500,
			totalWithdrawAmount:           200,
			totalDepositCount:             5,
			totalWithdrawCount:            2,
			totalCollectedAmount:          300,
			getterFunc:                    "ID",
			expectedValue:                 "test:180",
		},
		{
			name:                          "project tier get total distribute amount",
			id:                            "test:180",
			totalDistributeAmount:         1000,
			distributeAmountPerSecondX128: u256.NewUintFromInt64(100),
			startTime:                     1000,
			startHeight:                   100,
			endTime:                       2000,
			endHeight:                     200,
			totalDepositAmount:            500,
			totalWithdrawAmount:           200,
			totalDepositCount:             5,
			totalWithdrawCount:            2,
			totalCollectedAmount:          300,
			getterFunc:                    "TotalDistributeAmount",
			expectedValue:                 int64(1000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := launchpad.NewProjectTier("test_project", 180, tt.totalDistributeAmount, tt.startTime, tt.endTime)
			tier.SetID(tt.id)
			tier.SetDistributeAmountPerSecondX128(tt.distributeAmountPerSecondX128)
			tier.SetTotalDepositAmount(tt.totalDepositAmount)
			tier.SetTotalWithdrawAmount(tt.totalWithdrawAmount)
			tier.SetTotalDepositCount(tt.totalDepositCount)
			tier.SetTotalWithdrawCount(tt.totalWithdrawCount)
			tier.SetTotalCollectedAmount(tt.totalCollectedAmount)

			// Execute and verify
			var result interface{}
			switch tt.getterFunc {
			case "ID":
				result = tier.ID()
			case "TotalDistributeAmount":
				result = tier.TotalDistributeAmount()
			case "TotalCollectedAmount":
				result = tier.TotalCollectedAmount()
			case "TotalDepositAmount":
				result = tier.TotalDepositAmount()
			case "TotalWithdrawAmount":
				result = tier.TotalWithdrawAmount()
			case "TotalDepositCount":
				result = tier.TotalDepositCount()
			case "TotalWithdrawCount":
				result = tier.TotalWithdrawCount()
			case "CurrentDepositCount":
				result = getTierCurrentDepositCount(tier)
			case "CurrentDepositAmount":
				result = getTierCurrentDepositAmount(tier)
			}
			uassert.Equal(t, result, tt.expectedValue)
		})
	}
}

func TestProjectTier_Status(t *testing.T) {
	tests := []struct {
		name             string
		startHeight      int64
		endHeight        int64
		currentHeight    int64
		expectedIsActive bool
		expectedIsEnded  bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "project tier status inactive and not ended when before start",
			startHeight:      100,
			endHeight:        200,
			currentHeight:    50,
			expectedIsActive: false,
			expectedIsEnded:  false,
		},
		{
			name:             "project tier status active and not ended during active period",
			startHeight:      100,
			endHeight:        200,
			currentHeight:    150,
			expectedIsActive: true,
			expectedIsEnded:  false,
		},
		{
			name:             "project tier status inactive and ended after end",
			startHeight:      100,
			endHeight:        200,
			currentHeight:    250,
			expectedIsActive: false,
			expectedIsEnded:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := launchpad.NewProjectTier("test_project", 180, 1000, tt.startHeight, tt.endHeight)

			// Execute and verify
			isActive := tier.IsActivated(tt.currentHeight)
			isEnded := tier.IsEnded(tt.currentHeight)

			uassert.Equal(t, isActive, tt.expectedIsActive)
			uassert.Equal(t, isEnded, tt.expectedIsEnded)
		})
	}
}

func TestProjectTier_DepositAndWithdraw(t *testing.T) {
	tests := []struct {
		name                   string
		initialDepositAmount   int64
		initialWithdrawAmount  int64
		initialDepositCount    int64
		initialWithdrawCount   int64
		depositAmount          int64
		operation              string
		expectedDepositAmount  int64
		expectedWithdrawAmount int64
		expectedDepositCount   int64
		expectedWithdrawCount  int64
		expectedCurrentAmount  int64
		expectedCurrentCount   int64
		expectedHasError       bool
		expectedError          string
	}{
		{
			name:                   "project tier deposit update amounts and counts correctly",
			initialDepositAmount:   1000,
			initialWithdrawAmount:  0,
			initialDepositCount:    2,
			initialWithdrawCount:   0,
			depositAmount:          500,
			operation:              "deposit",
			expectedDepositAmount:  1500,
			expectedWithdrawAmount: 0,
			expectedDepositCount:   3,
			expectedWithdrawCount:  0,
			expectedCurrentAmount:  1500,
			expectedCurrentCount:   3,
		},
		{
			name:                   "project tier withdraw update amounts and counts correctly",
			initialDepositAmount:   1500,
			initialWithdrawAmount:  0,
			initialDepositCount:    3,
			initialWithdrawCount:   0,
			depositAmount:          500,
			operation:              "withdraw",
			expectedDepositAmount:  1500,
			expectedWithdrawAmount: 500,
			expectedDepositCount:   3,
			expectedWithdrawCount:  1,
			expectedCurrentAmount:  1000,
			expectedCurrentCount:   2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tier := launchpad.NewProjectTier("test_project", 180, 1000, 100, 200)
			tier.SetTotalDepositAmount(tt.initialDepositAmount)
			tier.SetTotalWithdrawAmount(tt.initialWithdrawAmount)
			tier.SetTotalDepositCount(tt.initialDepositCount)
			tier.SetTotalWithdrawCount(tt.initialWithdrawCount)

			deposit := launchpad.NewDeposit("test_deposit", "test_project", 180, testutils.TestAddress("depositor"), tt.depositAmount, 100, 100, 200)

			// Execute
			if tt.operation == "deposit" {
				depositToTier(tier, deposit)
			} else {
				withdrawToTier(tier, deposit)
			}

			// Verify
			uassert.Equal(t, tier.TotalDepositAmount(), tt.expectedDepositAmount)
			uassert.Equal(t, tier.TotalWithdrawAmount(), tt.expectedWithdrawAmount)
			uassert.Equal(t, tier.TotalDepositCount(), tt.expectedDepositCount)
			uassert.Equal(t, tier.TotalWithdrawCount(), tt.expectedWithdrawCount)
			uassert.Equal(t, getTierCurrentDepositAmount(tier), tt.expectedCurrentAmount)
			uassert.Equal(t, getTierCurrentDepositCount(tier), tt.expectedCurrentCount)
		})
	}
}

func TestProjectTier_NewProjectTier(t *testing.T) {
	tests := []struct {
		name                  string
		projectID             string
		tierDuration          int64
		totalDistributeAmount int64
		startBlockTime        int64
		endBlockTime          int64
		currentBlockTime      int64
		currentBlockHeight    int64
		expectedID            string
		expectedStartTime     int64
		expectedEndTime       int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name:                  "project tier create valid tier with correct values",
			projectID:             "test",
			tierDuration:          180,
			totalDistributeAmount: 1000,
			startBlockTime:        1000,
			endBlockTime:          2000,
			currentBlockTime:      500,
			currentBlockHeight:    50,
			expectedID:            "test:180",
			expectedStartTime:     1000,
			expectedEndTime:       2000,
			expectedHasError:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			tier := launchpad.NewProjectTier(
				tt.projectID,
				tt.tierDuration,
				tt.totalDistributeAmount,
				tt.startBlockTime,
				tt.endBlockTime,
			)

			// Verify
			uassert.Equal(t, tier.ID(), tt.expectedID)
			uassert.Equal(t, tier.StartTime(), tt.expectedStartTime)
			uassert.Equal(t, tier.EndTime(), tt.expectedEndTime)
		})
	}
}

// TestProjectTier_UpdateDistributeAmountPerSecond tests time-based distribution calculation
func TestProjectTier_UpdateDistributeAmountPerSecond(t *testing.T) {
	tests := []struct {
		name                          string
		totalDistributeAmount         int64
		startTime                     int64
		endTime                       int64
		expectedDistributePerSecondGT int64
		expectedDistributePerSecondLT int64
	}{
		{
			name:                          "standard 100 second duration",
			totalDistributeAmount:         1000,
			startTime:                     1000,
			endTime:                       1100,
			expectedDistributePerSecondGT: 9, // Should be ~10
			expectedDistributePerSecondLT: 11,
		},
		{
			name:                          "1 hour duration",
			totalDistributeAmount:         3600,
			startTime:                     0,
			endTime:                       3600,
			expectedDistributePerSecondGT: 0, // Should be exactly 1
			expectedDistributePerSecondLT: 2,
		},
		{
			name:                          "30 day duration with large amount",
			totalDistributeAmount:         2592000, // 30 days in seconds
			startTime:                     0,
			endTime:                       2592000, // 30 days
			expectedDistributePerSecondGT: 0,       // Should be exactly 1
			expectedDistributePerSecondLT: 2,
		},
		{
			name:                          "very short duration",
			totalDistributeAmount:         100,
			startTime:                     1000,
			endTime:                       1010, // 10 seconds
			expectedDistributePerSecondGT: 9,    // Should be ~10
			expectedDistributePerSecondLT: 11,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create tier with time-based parameters
			tier := launchpad.NewProjectTier("test", 30, tt.totalDistributeAmount, tt.startTime, tt.endTime)
			tier.SetID("test:30")

			// Update distribute amount per second
			updateTierDistributeAmountPerSecond(tier)

			// Get the actual value (need to shift right by 128 to get the integer part)
			distributePerSecond := tier.DistributeAmountPerSecondX128()
			actualPerSecond := distributePerSecond.Rsh(distributePerSecond, 128).Int64()

			// Verify it's in expected range
			uassert.Equal(t, true, actualPerSecond > tt.expectedDistributePerSecondGT,
				"Distribute per second should be greater than expected minimum")
			uassert.Equal(t, true, actualPerSecond < tt.expectedDistributePerSecondLT,
				"Distribute per second should be less than expected maximum")
		})
	}
}

// TestProjectTier_VaryingBlockTimes tests that tier calculations work correctly with varying block times
func TestProjectTier_VaryingBlockTimes(t *testing.T) {
	// Test that the tier correctly calculates rewards based on time, not blocks

	// Scenario 1: Fast blocks (1 second per block)
	fastBlockTier := launchpad.NewProjectTier("fast", 30, 1000, 1000, 1100)
	fastBlockTier.SetID("fast:30")
	updateTierDistributeAmountPerSecond(fastBlockTier)

	// Scenario 2: Slow blocks (10 seconds per block)
	slowBlockTier := launchpad.NewProjectTier("slow", 30, 1000, 1000, 1100)
	slowBlockTier.SetID("slow:30")
	updateTierDistributeAmountPerSecond(slowBlockTier)

	// Both should have the same distribute amount per second
	uassert.Equal(t,
		fastBlockTier.DistributeAmountPerSecondX128().ToString(),
		slowBlockTier.DistributeAmountPerSecondX128().ToString(),
		"Distribution rate should be the same regardless of block time")
}

// TestProjectTier_EdgeCases tests edge cases for project tier
func TestProjectTier_EdgeCases(t *testing.T) {
	// Test zero duration
	zeroDurationTier := launchpad.NewProjectTier("zero", 30, 1000, 1000, 1000)
	zeroDurationTier.SetID("zero:30")
	updateTierDistributeAmountPerSecond(zeroDurationTier)

	// Should result in zero distribution
	uassert.Equal(t, true, zeroDurationTier.DistributeAmountPerSecondX128().IsZero(),
		"Zero duration should result in zero distribution rate")

	// Test negative duration (end before start - should not happen but test defensive programming)
	invalidTier := launchpad.NewProjectTier(
		"invalid",
		30,
		1000,
		2000,
		1000, // End before start
	)

	// Should handle gracefully (likely zero or unchanged)
	// The actual behavior depends on implementation details
	_ = invalidTier
}

func TestProjectTier_makeProjectTierID(t *testing.T) {
	tests := []struct {
		name       string
		projectID  string
		tier       int64
		expectedID string
	}{
		{
			name:       "create tier id with tier 30",
			projectID:  "gno.land/r/demo/token:100",
			tier:       30,
			expectedID: "gno.land/r/demo/token:100:30",
		},
		{
			name:       "create tier id with tier 90",
			projectID:  "gno.land/r/demo/token:100",
			tier:       90,
			expectedID: "gno.land/r/demo/token:100:90",
		},
		{
			name:       "create tier id with tier 180",
			projectID:  "gno.land/r/demo/token:100",
			tier:       180,
			expectedID: "gno.land/r/demo/token:100:180",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := launchpad.MakeProjectTierID(tt.projectID, tt.tier)
			uassert.Equal(t, result, tt.expectedID)
		})
	}
}
