package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

// TestEmissionDistributionAcrossYears verifies that emission distribution remains
// even across years when block time changes
func TestEmissionDistributionAcrossYears(t *testing.T) {
	resetEmissionState(t)

	// Set up callback
	oldCallback := callbackEmissionChange
	callbackEmissionChange = func(amount int64) {}
	defer func() { callbackEmissionChange = oldCallback }()

	// Test different scenarios of block time changes
	scenarios := []struct {
		name           string
		changeAtYear   int64
		changeAtPercent int // percentage through the year
		oldBlockTime   int64
		newBlockTime   int64
	}{
		{
			name:           "Early change in year 2",
			changeAtYear:   2,
			changeAtPercent: 10,
			oldBlockTime:   2000,
			newBlockTime:   1000,
		},
		{
			name:           "Mid-year change in year 5",
			changeAtYear:   5,
			changeAtPercent: 50,
			oldBlockTime:   2000,
			newBlockTime:   3000,
		},
		{
			name:           "Late change in year 3",
			changeAtYear:   3,
			changeAtPercent: 90,
			oldBlockTime:   2000,
			newBlockTime:   1500,
		},
	}

	for _, sc := range scenarios {
		t.Run(sc.name, func(t *testing.T) {
			// Reset state for each scenario
			resetEmissionState(t)
			callbackEmissionChange = func(amount int64) {}

			// Skip to the target point in the year
			yearStart := GetHalvingYearStartBlock(sc.changeAtYear)
			yearEnd := GetHalvingYearEndBlock(sc.changeAtYear)
			blocksInYear := yearEnd - yearStart + 1
			targetHeight := yearStart + (blocksInYear * int64(sc.changeAtPercent) / 100)
			
			testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

			// Record expected total emissions for each year
			expectedTotals := make(map[int64]int64)
			for year := int64(1); year <= HALVING_END_YEAR; year++ {
				expectedTotals[year] = GetHalvingYearMaxAmount(year)
			}

			// Change block time
			testing.SetRealm(adminRealm)
			setAvgBlockTimeInMs(sc.newBlockTime)

			// Calculate actual total emissions for each year after change
			for year := sc.changeAtYear; year <= HALVING_END_YEAR; year++ {
				startBlock := GetHalvingYearStartBlock(year)
				endBlock := GetHalvingYearEndBlock(year)
				blocksInYear := endBlock - startBlock + 1
				amountPerBlock := GetAmountPerBlockPerHalvingYear(year)
				
				actualTotal := amountPerBlock * blocksInYear
				expectedTotal := expectedTotals[year]

				// For current year, need to account for already minted amount
				if year == sc.changeAtYear {
					mintedAmount := GetHalvingYearMintAmount(year)
					leftAmount := GetHalvingYearLeftAmount(year)
					
					// The sum of minted and left should equal max
					uassert.Equal(t, expectedTotal, mintedAmount+leftAmount,
						ufmt.Sprintf("%s: Year %d minted+left should equal max", sc.name, year))
					
					// Calculate expected emission for remaining blocks
					remainingBlocks := endBlock - std.ChainHeight()
					expectedRemainingEmission := amountPerBlock * remainingBlocks
					
					// Should be close to left amount (within 1%)
					diff := expectedRemainingEmission - leftAmount
					if diff < 0 {
						diff = -diff
					}
					tolerance := leftAmount / 100
					
					uassert.True(t, diff <= tolerance,
						ufmt.Sprintf("%s: Year %d remaining emission incorrect. Left: %d, Expected: %d",
							sc.name, year, leftAmount, expectedRemainingEmission))
				} else {
					// For future years, total emission should match max amount
					diff := actualTotal - expectedTotal
					if diff < 0 {
						diff = -diff
					}
					
					// Allow 1% tolerance for rounding
					tolerance := expectedTotal / 100
					
					uassert.True(t, diff <= tolerance,
						ufmt.Sprintf("%s: Year %d total emission incorrect. Expected: %d, Got: %d, Diff: %d",
							sc.name, year, expectedTotal, actualTotal, diff))
				}
			}
		})
	}
}

// TestEmissionRateConsistencyAcrossYears verifies that the emission rate
// calculations are consistent when block time changes
func TestEmissionRateConsistencyAcrossYears(t *testing.T) {
	resetEmissionState(t)

	// Set up callback
	oldCallback := callbackEmissionChange
	callbackEmissionChange = func(amount int64) {}
	defer func() { callbackEmissionChange = oldCallback }()

	// Skip to year 3
	targetHeight := GetHalvingYearStartBlock(3) + 1000
	testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

	// Change block time from 2000ms to 1000ms
	testing.SetRealm(adminRealm)
	setAvgBlockTimeInMs(1000)

	// For each future year, verify the relationship between
	// blocks per year and emission per block
	for year := int64(4); year <= HALVING_END_YEAR; year++ {
		maxAmount := GetHalvingYearMaxAmount(year)
		amountPerBlock := GetAmountPerBlockPerHalvingYear(year)
		startBlock := GetHalvingYearStartBlock(year)
		endBlock := GetHalvingYearEndBlock(year)
		blocksInYear := endBlock - startBlock + 1

		// Calculate daily emission rate
		dailyAmount := maxAmount / DAY_PER_YEAR
		expectedAmountPerBlock := dailyAmount / blockPerDay

		// The calculated amount per block should match expected
		uassert.Equal(t, expectedAmountPerBlock, amountPerBlock,
			ufmt.Sprintf("Year %d: amount per block mismatch", year))

		// Total emission should be close to max amount
		totalEmission := amountPerBlock * blocksInYear
		diff := totalEmission - maxAmount
		if diff < 0 {
			diff = -diff
		}
		
		// Allow small tolerance for integer division
		tolerance := maxAmount / 100
		uassert.True(t, diff <= tolerance,
			ufmt.Sprintf("Year %d: total emission deviates. Max: %d, Total: %d",
				year, maxAmount, totalEmission))
	}
}

// TestEmissionEvennessScore calculates an "evenness score" to measure
// how evenly emissions are distributed across years after block time changes
func TestEmissionEvennessScore(t *testing.T) {
	resetEmissionState(t)

	// Set up callback
	oldCallback := callbackEmissionChange
	callbackEmissionChange = func(amount int64) {}
	defer func() { callbackEmissionChange = oldCallback }()

	// Skip to year 4
	targetHeight := GetHalvingYearStartBlock(4) + 500
	testing.SkipHeights(targetHeight - std.ChainHeight() - 1)

	// Test multiple block time changes
	blockTimes := []int64{1500, 2500, 1800, 2200}
	
	for _, newBlockTime := range blockTimes {
		testing.SetRealm(adminRealm)
		setAvgBlockTimeInMs(newBlockTime)

		// Calculate "evenness score" - the maximum deviation from expected
		maxDeviation := int64(0)
		
		for year := int64(5); year <= HALVING_END_YEAR; year++ {
			maxAmount := GetHalvingYearMaxAmount(year)
			amountPerBlock := GetAmountPerBlockPerHalvingYear(year)
			startBlock := GetHalvingYearStartBlock(year)
			endBlock := GetHalvingYearEndBlock(year)
			blocksInYear := endBlock - startBlock + 1
			
			totalEmission := amountPerBlock * blocksInYear
			deviation := totalEmission - maxAmount
			if deviation < 0 {
				deviation = -deviation
			}
			
			if deviation > maxDeviation {
				maxDeviation = deviation
			}
		}

		// Maximum deviation should be less than 1% of any year's emission
		// This ensures emissions remain evenly distributed
		maxAllowedDeviation := GetHalvingYearMaxAmount(5) / 100 // 1% of a typical year
		
		uassert.True(t, maxDeviation <= maxAllowedDeviation,
			ufmt.Sprintf("Block time %d: max deviation %d exceeds allowed %d",
				newBlockTime, maxDeviation, maxAllowedDeviation))
	}
}