package gns

import "time"

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

// GetHalvingYear returns the halving year (1-12) for a given timestamp.
func GetHalvingYear(timestamp int64) int64 {
	return getEmissionState().getCurrentYear(timestamp)
}

// GetCurrentYear returns the current halving year (1-12) or 0 if emission is not active.
func GetCurrentYear() int64 {
	return getEmissionState().getCurrentYear(time.Now().Unix())
}

// GetEmissionAmountPerSecondInRange returns halving timestamps and emission rates for the given time range.
// Returns two slices: timestamps when halving periods start and corresponding emission rates per second.
func GetEmissionAmountPerSecondInRange(fromTime, toTime int64) ([]int64, []int64) {
	halvingData := getEmissionState().getHalvingData()
	halvingTimes := make([]int64, 0, HALVING_END_YEAR)
	halvingEmissions := make([]int64, 0, HALVING_END_YEAR)

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

	return halvingTimes, halvingEmissions
}

// GetEmissionAmountPerSecondByTimestamp returns the emission rate per second for a given timestamp.
// Returns 0 if timestamp is outside emission period.
func GetEmissionAmountPerSecondByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearAmountPerSecond(year)
}

// GetEmissionLeftAmountByTimestamp returns the remaining emission amount for the halving year at given timestamp.
// Returns 0 if timestamp is outside emission period.
func GetEmissionLeftAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearLeftAmount(year)
}

// GetEmissionAccumulatedAmountByTimestamp returns the accumulated emission amount for the halving year at given timestamp.
// Returns 0 if timestamp is outside emission period.
func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearAccumulatedAmount(year)
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

// GetHalvingYearMintAmount returns the amount of tokens minted for the specified halving year.
func GetHalvingYearMintAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMintedAmount(year)
}

// GetHalvingYearLeftAmount returns the remaining token issuance for the specified halving year.
func GetHalvingYearLeftAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getLeftAmount(year)
}

// GetHalvingYearAccuAmount returns the accumulated token issuance for the specified halving year.
func GetHalvingYearAccuAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAccumAmount(year)
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

// GetEmissionStartHeight returns the block height when emission schedule was initialized.
func GetEmissionStartHeight() int64 {
	return getEmissionState().getStartHeight()
}

// GetEmissionStartTimestamp returns the timestamp when emission schedule begins.
func GetEmissionStartTimestamp() int64 {
	return getEmissionState().getStartTimestamp()
}

// GetEmissionEndTimestamp returns the timestamp when emission schedule ends.
func GetEmissionEndTimestamp() int64 {
	return getEmissionState().getEndTimestamp()
}

// GetHalvingYearInfo returns the halving year, start timestamp, and end timestamp for a given timestamp.
// Returns (year, startTimestamp, endTimestamp). Year is 0 if outside emission period.
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
