package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

// TestEmissionBoundaryConditions tests for emission at year boundaries
func TestEmissionBoundaryConditions(t *testing.T) {
	resetEmissionState(t)

	tests := []struct {
		name           string
		height         int64
		expectedAmount int64
		description    string
	}{
		{
			name:           "Emission at first block of year 1",
			height:         GetHalvingYearStartBlock(1),
			expectedAmount: GetAmountPerBlockPerHalvingYear(1),
			description:    "Should return year 1 amount at first block",
		},
		{
			name:           "Emission at last block of year 1",
			height:         GetHalvingYearEndBlock(1),
			expectedAmount: GetAmountPerBlockPerHalvingYear(1),
			description:    "Should return year 1 amount at last block",
		},
		{
			name:           "Emission at first block of year 2",
			height:         GetHalvingYearStartBlock(2),
			expectedAmount: GetAmountPerBlockPerHalvingYear(2),
			description:    "Should return year 2 amount at first block",
		},
		{
			name:           "Emission at boundary between year 6 and 7",
			height:         GetHalvingYearEndBlock(6) + 1,
			expectedAmount: GetAmountPerBlockPerHalvingYear(7),
			description:    "Should transition correctly between halving periods",
		},
		{
			name:           "Emission at last block of year 12",
			height:         GetHalvingYearEndBlock(12),
			expectedAmount: GetAmountPerBlockPerHalvingYear(12),
			description:    "Should return year 12 amount at last emission block",
		},
		{
			name:           "Emission after year 12 ends",
			height:         GetHalvingYearEndBlock(12) + 1,
			expectedAmount: 0,
			description:    "Should return 0 after emission period ends",
		},
		{
			name:           "Emission far after emission period",
			height:         GetHalvingYearEndBlock(12) + 1000000,
			expectedAmount: 0,
			description:    "Should return 0 far after emission ends",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount := AmountByHeight(tt.height)
			uassert.Equal(t, tt.expectedAmount, amount,
				"%s: %s", tt.name, tt.description)
		})
	}
}

// TestBlockTimeChangeImpact tests the impact of block time changes on emission
func TestBlockTimeChangeImpact(t *testing.T) {
	tests := []struct {
		name                  string
		initialBlockTime      int64
		changeAtYear          int64
		changeAtPercent       int // percentage of year completed
		newBlockTime          int64
		expectedYearEndChange bool
		expectedAmountChange  bool
		description           string
	}{
		{
			name:                  "Decrease block time early in year",
			initialBlockTime:      2000,
			changeAtYear:          3,
			changeAtPercent:       20,
			newBlockTime:          1000,
			expectedYearEndChange: true,
			expectedAmountChange:  true,
			description:           "Should extend year and decrease amount per block",
		},
		{
			name:                  "Increase block time early in year",
			initialBlockTime:      2000,
			changeAtYear:          3,
			changeAtPercent:       20,
			newBlockTime:          3000,
			expectedYearEndChange: true,
			expectedAmountChange:  true,
			description:           "Should shorten year and increase amount per block",
		},
		{
			name:                  "Minimal block time change",
			initialBlockTime:      2000,
			changeAtYear:          5,
			changeAtPercent:       50,
			newBlockTime:          2001,
			expectedYearEndChange: true,
			expectedAmountChange:  true,
			description:           "Even small changes should affect calculations",
		},
		{
			name:                  "Block time change late in year",
			initialBlockTime:      2000,
			changeAtYear:          2,
			changeAtPercent:       90,
			newBlockTime:          1500,
			expectedYearEndChange: true,
			expectedAmountChange:  true,
			description:           "Should still adjust remaining blocks correctly",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetEmissionState(t)

			// Skip to the target year and percentage
			targetHeight := GetHalvingYearStartBlock(tt.changeAtYear)
			blocksInYear := GetHalvingYearEndBlock(tt.changeAtYear) - GetHalvingYearStartBlock(tt.changeAtYear) + 1
			skipBlocks := (blocksInYear * int64(tt.changeAtPercent)) / 100
			targetHeight += skipBlocks

			// Skip to target height
			testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

			// Record values before change
			prevEndBlock := GetHalvingYearEndBlock(tt.changeAtYear)
			prevAmountPerBlock := GetAmountPerBlockPerHalvingYear(tt.changeAtYear)

			// Set up admin context and callback
			testing.SetRealm(adminRealm)

			setAvgBlockTimeInMs(tt.newBlockTime)

			newEndBlock := GetHalvingYearEndBlock(tt.changeAtYear)
			newAmountPerBlock := GetAmountPerBlockPerHalvingYear(tt.changeAtYear)

			if tt.expectedYearEndChange {
				uassert.NotEqual(t, prevEndBlock, newEndBlock,
					"%s: Year end block should change", tt.name)
			}

			if tt.expectedAmountChange {
				uassert.NotEqual(t, prevAmountPerBlock, newAmountPerBlock,
					"%s: Amount per block should change", tt.name)
			}

			// Verify that future years are also adjusted
			if tt.changeAtYear < HALVING_END_YEAR {
				nextYearStart := GetHalvingYearStartBlock(tt.changeAtYear + 1)
				uassert.Equal(t, newEndBlock+1, nextYearStart,
					"%s: Next year should start immediately after current year ends", tt.name)
			}
		})
	}
}

// TestEmissionStateConsistency tests that emission state remains consistent
func TestEmissionStateConsistency(t *testing.T) {
	resetEmissionState(t)

	tests := []struct {
		name        string
		operation   func()
		validation  func(*testing.T)
		description string
	}{
		{
			name: "Initial state consistency",
			operation: func() {
				// No operation, just check initial state
			},
			validation: func(t *testing.T) {
				totalMaxAmount := int64(0)
				for year := int64(1); year <= 12; year++ {
					totalMaxAmount += GetHalvingYearMaxAmount(year)

					if year == 1 {
						uassert.Equal(t, GetHalvingYearMaxAmount(year), GetHalvingYearAccuAmount(year),
							"Year 1 accumulated amount should equal max amount")
					} else {
						expected := GetHalvingYearAccuAmount(year-1) + GetHalvingYearMaxAmount(year)
						uassert.Equal(t, expected, GetHalvingYearAccuAmount(year),
							"Accumulated amount should be sum of all previous years")
					}

					// Verify initial minted/left amounts
					uassert.Equal(t, int64(0), GetHalvingYearMintAmount(year),
						"Initial minted amount should be 0")
					uassert.Equal(t, GetHalvingYearMaxAmount(year), GetHalvingYearLeftAmount(year),
						"Initial left amount should equal max amount")
				}

				// Total should be 900 billion (with 6 decimals)
				uassert.Equal(t, int64(900_000_000_000_000), totalMaxAmount,
					"Total emission should be 900 billion")
			},
			description: "Verify initial emission state is consistent",
		},
		{
			name: "Minting updates state correctly",
			operation: func() {
				// Skip to middle of year 3 and mint
				targetHeight := (GetHalvingYearStartBlock(3) + GetHalvingYearEndBlock(3)) / 2
				testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

				// Simulate minting by calling GetEmission
				_ = GetEmission()
			},
			validation: func(t *testing.T) {
				year := int64(3)
				mintedAmount := GetHalvingYearMintAmount(year)
				leftAmount := GetHalvingYearLeftAmount(year)
				maxAmount := GetHalvingYearMaxAmount(year)

				// Verify conservation of tokens
				uassert.Equal(t, maxAmount, mintedAmount+leftAmount,
					"Minted + Left should equal Max amount")

				// Verify minting occurred
				uassert.True(t, mintedAmount > 0,
					"Minted amount should be greater than 0")
				uassert.True(t, leftAmount < maxAmount,
					"Left amount should be less than max amount")
			},
			description: "Verify minting updates state consistently",
		},
		{
			name: "Year boundaries maintain continuity",
			operation: func() {
				// No additional operation needed
			},
			validation: func(t *testing.T) {
				for year := int64(1); year < 12; year++ {
					endBlock := GetHalvingYearEndBlock(year)
					nextStartBlock := GetHalvingYearStartBlock(year + 1)

					uassert.Equal(t, endBlock+1, nextStartBlock,
						"Year end should be followed by next year start")
				}
			},
			description: "Verify year boundaries are continuous",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.operation()
			tt.validation(t)
		})
	}
}

// TestEmissionAfterBlockTimeChange tests emission calculations after block time changes
func TestEmissionAfterBlockTimeChange(t *testing.T) {
	tests := []struct {
		name             string
		initialBlockTime int64
		newBlockTime     int64
		testYear         int64
		description      string
	}{
		{
			name:             "Halve block time doubles blocks per year",
			initialBlockTime: 2000,
			newBlockTime:     1000,
			testYear:         5,
			description:      "Halving block time should roughly double remaining blocks",
		},
		{
			name:             "Double block time halves blocks per year",
			initialBlockTime: 2000,
			newBlockTime:     4000,
			testYear:         2,
			description:      "Doubling block time should roughly halve remaining blocks",
		},
		{
			name:             "Multiple changes in same year",
			initialBlockTime: 2000,
			newBlockTime:     1500,
			testYear:         3,
			description:      "Multiple block time changes should compound correctly",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetEmissionState(t)

			// Skip to 30% of test year
			yearStart := GetHalvingYearStartBlock(tt.testYear)
			yearEnd := GetHalvingYearEndBlock(tt.testYear)
			targetHeight := yearStart + (yearEnd-yearStart)*3/10

			testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

			// Record state before change
			heightBeforeChange := std.ChainHeight()
			remainingBlocksBefore := yearEnd - heightBeforeChange
			leftAmountBefore := GetHalvingYearLeftAmount(tt.testYear)

			// Change block time
			testing.SetRealm(adminRealm)
			setAvgBlockTimeInMs(tt.newBlockTime)

			// Check adjustments
			newYearEnd := GetHalvingYearEndBlock(tt.testYear)
			remainingBlocksAfter := newYearEnd - heightBeforeChange
			newAmountPerBlock := GetAmountPerBlockPerHalvingYear(tt.testYear)

			// Calculate expected remaining blocks based on time ratio
			expectedRemainingBlocks := remainingBlocksBefore * tt.initialBlockTime / tt.newBlockTime

			// Allow 1 block difference due to rounding
			diff := remainingBlocksAfter - expectedRemainingBlocks
			if diff < 0 {
				diff = -diff
			}
			uassert.True(t, diff <= 1,
				"%s: Remaining blocks should be adjusted proportionally", tt.name)

			// Verify amount per block is recalculated to maintain correct total
			expectedTotalRemaining := newAmountPerBlock * remainingBlocksAfter

			amountDiff := leftAmountBefore - expectedTotalRemaining
			if amountDiff < 0 {
				amountDiff = -amountDiff
			}
			uassert.True(t, amountDiff <= newAmountPerBlock,
				"%s: Total remaining emission should be preserved", tt.name)

			// If we change back, verify amounts are restored (approximately)
			if tt.name == "Multiple changes in same year" {
				setAvgBlockTimeInMs(tt.initialBlockTime)

				finalAmountPerBlock := GetAmountPerBlockPerHalvingYear(tt.testYear)
				finalYearEnd := GetHalvingYearEndBlock(tt.testYear)

				// Due to rounding, exact restoration isn't guaranteed,
				// but should be very close
				uassert.NotEqual(t, int64(0), finalAmountPerBlock,
					"%s: Amount per block should not be zero after restoration", tt.name)
				uassert.True(t, finalYearEnd > heightBeforeChange,
					"%s: Year should not have ended after restoration", tt.name)
			}
		})
	}
}

// TestFutureYearEmissionRecalculation tests that emission rates for future years
// are properly recalculated when average block time changes
func TestFutureYearEmissionRecalculation(t *testing.T) {
	resetEmissionState(t)

	// Skip to year 3 (to have both current and future years)
	targetHeight := GetHalvingYearStartBlock(3) + 1000
	testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

	// Record emission rates for all years before block time change
	emissionRatesBefore := make(map[int64]int64)
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		emissionRatesBefore[year] = GetAmountPerBlockPerHalvingYear(year)
	}

	// Change block time (decrease to 1000ms from 2000ms)
	// This should roughly double the blocks per year
	testing.SetRealm(adminRealm)
	setAvgBlockTimeInMs(1000)

	// Check current year (year 3)
	currentYear := HalvingYearByHeight(std.ChainHeight())
	uassert.Equal(t, int64(3), currentYear, "Should be in year 3")

	// Verify that future years' emission rates were recalculated
	for year := currentYear + 1; year <= HALVING_END_YEAR; year++ {
		emissionRateAfter := GetAmountPerBlockPerHalvingYear(year)
		emissionRateBefore := emissionRatesBefore[year]

		// Since block time was halved, emission per block should be roughly halved
		// to maintain the same total emission per year
		expectedRatio := float64(emissionRateBefore) / float64(emissionRateAfter)

		// Allow for some rounding error (within 5%)
		if expectedRatio < 1.9 || expectedRatio > 2.1 {
			t.Errorf("Year %d: emission rate not properly adjusted. Before: %d, After: %d, Ratio: %.2f",
				year, emissionRateBefore, emissionRateAfter, expectedRatio)
		}

		// Verify that the total emission for the year remains roughly the same
		blocksInYear := GetHalvingYearEndBlock(year) - GetHalvingYearStartBlock(year) + 1
		totalEmissionAfter := emissionRateAfter * blocksInYear
		maxAmount := GetHalvingYearMaxAmount(year)

		// The total emission should be close to max amount (within 1%)
		diff := totalEmissionAfter - maxAmount
		if diff < 0 {
			diff = -diff
		}
		tolerance := maxAmount / 100 // 1% tolerance

		uassert.True(t, diff <= tolerance,
			ufmt.Sprintf("Year %d: total emission deviates too much. Expected: %d, Got: %d, Diff: %d",
				year, maxAmount, totalEmissionAfter, diff))
	}
}
