package gns

import (
	"time"

	gnsmath "gno.land/p/gnoswap/gnsmath"
)

// GetMaxEmissionAmount returns the maximum amount of emission allowed.
func GetMaxEmissionAmount() int64 {
	return MAX_EMISSION_AMOUNT
}

// GetMaximumSupply returns the maximum supply of gns tokens.
func GetMaximumSupply() int64 {
	return MAXIMUM_SUPPLY
}

// GetInitialMintAmount returns the initial amount of gns tokens to be minted.
func GetInitialMintAmount() int64 {
	return INITIAL_MINT_AMOUNT
}

// IsEmissionInitialized returns true if emission schedule has been initialized.
func IsEmissionInitialized() bool {
	return getEmissionState().isInitialized()
}

// IsEmissionActive returns true if emission is currently active based on current time.
func IsEmissionActive() bool {
	return getEmissionState().isActive(time.Now().Unix())
}

// IsEmissionEnded returns true if emission schedule has completed.
func IsEmissionEnded() bool {
	return getEmissionState().isEnded(time.Now().Unix())
}

// GetHalvingYear returns the halving year for a timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to query
//
// Returns:
//   - year: halving year in [1, 12], or 0 outside the emission schedule
func GetHalvingYear(timestamp int64) int64 {
	return getEmissionState().getCurrentYear(timestamp)
}

// GetCurrentYear returns the current halving year (1-12) or 0 if emission is not active.
func GetCurrentYear() int64 {
	return getEmissionState().getCurrentYear(time.Now().Unix())
}

// GetEmissionAmountPerSecondInRange returns emission-rate change points in a time range.
//
// Parameters:
//   - fromTime: inclusive Unix timestamp
//   - toTime: inclusive Unix timestamp
//
// Returns:
//   - timestamps: timestamps where the emission rate changes
//   - amounts: emission rate per second at each timestamp
func GetEmissionAmountPerSecondInRange(fromTime, toTime int64) ([]int64, []int64) {
	if fromTime > toTime {
		return nil, nil
	}

	halvingData := getEmissionState().getHalvingData()
	halvingTimes := make([]int64, 0, HALVING_END_YEAR+1)
	halvingEmissions := make([]int64, 0, HALVING_END_YEAR+1)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		startTimestamp := halvingData.getStartTimestamp(year)
		if startTimestamp < fromTime {
			continue
		}

		if toTime < startTimestamp {
			break
		}

		halvingTimes = append(halvingTimes, startTimestamp)
		halvingEmissions = append(halvingEmissions, halvingData.getAmountPerSecond(year))
	}

	emissionEndTimestamp := halvingData.getEndTimestamp(HALVING_END_YEAR)
	if fromTime <= emissionEndTimestamp && emissionEndTimestamp < toTime {
		halvingTimes = append(halvingTimes, gnsmath.SafeAddInt64(emissionEndTimestamp, 1))
		halvingEmissions = append(halvingEmissions, 0)
	}

	return halvingTimes, halvingEmissions
}

// GetEmissionAmountPerSecondByTimestamp returns the emission rate at a timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to query
//
// Returns:
//   - amount: emission rate per second, or 0 outside the emission schedule
func GetEmissionAmountPerSecondByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearAmountPerSecond(year)
}

// GetEmissionLeftAmountByTimestamp returns the unminted allocation at a timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to query
//
// Returns:
//   - amount: remaining allocation for the halving year, or 0 outside the schedule
func GetEmissionLeftAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearLeftAmount(year)
}

// GetEmissionAccumulatedAmountByTimestamp returns the minted allocation at a timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to query
//
// Returns:
//   - amount: minted allocation for the halving year, or 0 outside the schedule
func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearMintedAmount(year)
}

// GetHalvingYearStartTimestamp returns the start timestamp for the specified halving year.
func GetHalvingYearStartTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearEndTimestamp returns the end timestamp for the specified halving year.
func GetHalvingYearEndTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getEndTimestamp(year)
}

// GetHalvingYearMaxAmount returns the maximum token issuance for the specified halving year.
func GetHalvingYearMaxAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMaxAmount(year)
}

// GetHalvingYearLeftAmount returns the remaining token issuance for the specified halving year.
func GetHalvingYearLeftAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getLeftAmount(year)
}

// GetHalvingYearMintedAmount returns the minted token issuance for the specified halving year.
func GetHalvingYearMintedAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMintedAmount(year)
}

// GetAmountPerSecondPerHalvingYear returns the emission rate per second for the specified halving year.
func GetAmountPerSecondPerHalvingYear(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAmountPerSecond(year)
}

// GetHalvingAmountsPerYear returns the total emission amount allocated for the specified year.
// Returns 0 if year is outside the valid range (1-12).
func GetHalvingAmountsPerYear(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return halvingAmountsPerYear[year-1]
}

// GetEmissionCreatedHeight returns the block height when emission schedule was created.
func GetEmissionCreatedHeight() int64 {
	return getEmissionState().getCreatedHeight()
}

// GetEmissionStartTimestamp returns the timestamp when emission schedule begins.
func GetEmissionStartTimestamp() int64 {
	return getEmissionState().getStartTimestamp()
}

// GetEmissionEndTimestamp returns the timestamp when emission schedule ends.
func GetEmissionEndTimestamp() int64 {
	return getEmissionState().getEndTimestamp()
}

// GetHalvingYearInfo returns the halving interval containing a timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to query
//
// Returns:
//   - year: halving year in [1, 12], or 0 outside the emission schedule
//   - startTimestamp: inclusive start timestamp of the halving year
//   - endTimestamp: inclusive end timestamp of the halving year
func GetHalvingYearInfo(timestamp int64) (int64, int64, int64) {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)

	// If outside emission period, return 0 values
	if year == 0 {
		return 0, 0, 0
	}

	// Use cached timestamps from HalvingData
	halvingData := state.getHalvingData()
	return year, halvingData.getStartTimestamp(year), halvingData.getEndTimestamp(year)
}

// GetHalvingInfo returns a copy of the configured halving schedule.
//
// Returns:
//   - halvingData: independent copy of the schedule data
func GetHalvingInfo() *HalvingData {
	return getEmissionState().getHalvingData().Clone()
}

// CalculateMintGnsAmount calculates GNS mintable over a timestamp range.
//
// Parameters:
//   - fromTimestamp: inclusive range start
//   - toTimestamp: inclusive range end
//
// Returns:
//   - amount: mintable GNS amount, or 0 for an invalid range
func CalculateMintGnsAmount(fromTimestamp, toTimestamp int64) int64 {
	state := getEmissionState().Clone()

	amountToMint, err := calculateAmountToMint(state, fromTimestamp, toTimestamp)
	if err != nil {
		return 0
	}

	return amountToMint
}
