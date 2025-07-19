package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

// TestFutureYearEmissionRecalculation tests that emission rates for future years
// are properly recalculated when average block time changes
func TestFutureYearEmissionRecalculation(t *testing.T) {
	resetEmissionState(t)

	// Set up callback to avoid panic
	oldCallback := callbackEmissionChange
	callbackEmissionChange = func(amount int64) {}
	defer func() { callbackEmissionChange = oldCallback }()

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

// TestMultipleBlockTimeChanges tests that emission rates remain consistent
// after multiple block time changes
func TestMultipleBlockTimeChanges(t *testing.T) {
	resetEmissionState(t)

	// Set up callback
	oldCallback := callbackEmissionChange
	callbackEmissionChange = func(amount int64) {}
	defer func() { callbackEmissionChange = oldCallback }()

	// Skip to year 2
	targetHeight := GetHalvingYearStartBlock(2) + 500
	testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

	// Record initial max amounts for verification
	maxAmounts := make(map[int64]int64)
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		maxAmounts[year] = GetHalvingYearMaxAmount(year)
	}

	testing.SetRealm(adminRealm)

	// Perform multiple block time changes
	blockTimes := []int64{1500, 3000, 1000, 2500}

	for _, blockTime := range blockTimes {
		setAvgBlockTimeInMs(blockTime)

		// Verify emission rates for all future years
		currentYear := HalvingYearByHeight(std.ChainHeight())

		for year := currentYear + 1; year <= HALVING_END_YEAR; year++ {
			emissionRate := GetAmountPerBlockPerHalvingYear(year)
			blocksInYear := GetHalvingYearEndBlock(year) - GetHalvingYearStartBlock(year) + 1

			// Calculate total emission for the year
			totalEmission := emissionRate * blocksInYear
			expectedMax := maxAmounts[year]

			// Verify total emission is close to expected (within 1%)
			diff := totalEmission - expectedMax
			if diff < 0 {
				diff = -diff
			}
			tolerance := expectedMax / 100

			uassert.True(t, diff <= tolerance,
				ufmt.Sprintf("After setting block time to %d, year %d emission incorrect. Expected: %d, Got: %d",
					blockTime, year, expectedMax, totalEmission))
		}
	}
}

// TestFutureYearEmissionWithPartialCurrentYear tests emission rate calculation
// when block time changes partway through the current year
func TestFutureYearEmissionWithPartialCurrentYear(t *testing.T) {
	resetEmissionState(t)

	// Set up callback
	oldCallback := callbackEmissionChange
	callbackEmissionChange = func(amount int64) {}
	defer func() { callbackEmissionChange = oldCallback }()

	// Skip to 75% through year 4
	year4Start := GetHalvingYearStartBlock(4)
	year4End := GetHalvingYearEndBlock(4)
	targetHeight := year4Start + (year4End-year4Start)*3/4
	testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

	// Mint some tokens to simulate partial emission
	for i := 0; i < 100; i++ {
		GetEmission()
		testing.SkipHeights(1)
	}

	// Record state before change
	year4LeftBefore := GetHalvingYearLeftAmount(4)
	futureEmissionsBefore := make(map[int64]int64)
	for year := int64(5); year <= HALVING_END_YEAR; year++ {
		futureEmissionsBefore[year] = GetAmountPerBlockPerHalvingYear(year)
	}

	// Change block time
	testing.SetRealm(adminRealm)
	newBlockTime := int64(1200) // From 2000ms to 1200ms
	setAvgBlockTimeInMs(newBlockTime)

	// Verify current year uses remaining amount
	year4EmissionAfter := GetAmountPerBlockPerHalvingYear(4)
	year4EndAfter := GetHalvingYearEndBlock(4)
	remainingBlocks := year4EndAfter - std.ChainHeight()
	expectedYear4Total := year4EmissionAfter * remainingBlocks

	// The total should be close to the left amount before change
	diff := expectedYear4Total - year4LeftBefore
	if diff < 0 {
		diff = -diff
	}
	tolerance := year4LeftBefore / 100 // 1% tolerance

	uassert.True(t, diff <= tolerance,
		ufmt.Sprintf("Year 4 remaining emission incorrect. Left before: %d, Expected total: %d",
			year4LeftBefore, expectedYear4Total))

	// Verify future years use full year calculation
	for year := int64(5); year <= HALVING_END_YEAR; year++ {
		emissionAfter := GetAmountPerBlockPerHalvingYear(year)
		blocksInYear := GetHalvingYearEndBlock(year) - GetHalvingYearStartBlock(year) + 1
		totalEmission := emissionAfter * blocksInYear
		maxAmount := GetHalvingYearMaxAmount(year)

		// Total emission should match max amount (within 1%)
		diff := totalEmission - maxAmount
		if diff < 0 {
			diff = -diff
		}
		tolerance := maxAmount / 100

		uassert.True(t, diff <= tolerance,
			ufmt.Sprintf("Year %d total emission incorrect. Max: %d, Total: %d",
				year, maxAmount, totalEmission))
	}
}
