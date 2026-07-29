package gns

import "time"

// GetMaxEmissionAmount returns the maximum amount of emission allowed.
//
// Returns:
//   - amount: maximum emission amount
func GetMaxEmissionAmount() int64 {
	return MAX_EMISSION_AMOUNT
}

// GetMaximumSupply returns the maximum supply of gns tokens.
//
// Returns:
//   - supply: maximum token supply
func GetMaximumSupply() int64 {
	return MAXIMUM_SUPPLY
}

// GetInitialMintAmount returns the initial amount of gns tokens to be minted.
//
// Returns:
//   - amount: initial mint amount
func GetInitialMintAmount() int64 {
	return INITIAL_MINT_AMOUNT
}

// IsEmissionInitialized returns true if emission schedule has been initialized.
//
// Returns:
//   - initialized: true if emission is initialized
func IsEmissionInitialized() bool {
	return getEmissionState().isInitialized()
}

// IsEmissionActive returns true if emission is currently active based on current time.
//
// Returns:
//   - active: true if emission is active
func IsEmissionActive() bool {
	return getEmissionState().isActive(time.Now().Unix())
}

// IsEmissionEnded returns true if emission schedule has completed.
//
// Returns:
//   - ended: true if emission has ended
func IsEmissionEnded() bool {
	return getEmissionState().isEnded(time.Now().Unix())
}

// GetHalvingYear returns the halving year (1-12) for a given timestamp.
//
// Parameters:
//   - timestamp: timestamp to check
//
// Returns:
//   - year: halving year (1-12) or 0 if outside emission period
func GetHalvingYear(timestamp int64) int64 {
	return getEmissionState().getCurrentYear(timestamp)
}

// GetCurrentYear returns the current halving year (1-12) or 0 if emission is not active.
//
// Returns:
//   - year: current halving year
func GetCurrentYear() int64 {
	return getEmissionState().getCurrentYear(time.Now().Unix())
}

// GetEmissionAmountPerSecondInRange returns halving timestamps and emission rates for the given time range.
//
// Parameters:
//   - fromTime: start timestamp
//   - toTime: end timestamp
//
// Returns:
//   - halvingTimes: timestamps when halving periods start
//   - halvingEmissions: emission rates per second at each halving
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
//
// Parameters:
//   - timestamp: timestamp to check
//
// Returns:
//   - amount: emission rate per second, or 0 if outside emission period
func GetEmissionAmountPerSecondByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearAmountPerSecond(year)
}

// GetEmissionLeftAmountByTimestamp returns the remaining emission amount for the halving year at given timestamp.
//
// Parameters:
//   - timestamp: timestamp to check
//
// Returns:
//   - amount: remaining emission amount, or 0 if outside emission period
func GetEmissionLeftAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearLeftAmount(year)
}

// GetEmissionAccumulatedAmountByTimestamp returns the accumulated emission amount for the halving year at given timestamp.
//
// Parameters:
//   - timestamp: timestamp to check
//
// Returns:
//   - amount: accumulated emission amount, or 0 if outside emission period
func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearAccumulatedAmount(year)
}

// GetEmissionCreatedHeight returns the block height when emission schedule was created.
//
// Returns:
//   - height: block height when emission schedule was created
func GetEmissionCreatedHeight() int64 {
	return getEmissionState().getCreatedHeight()
}

// GetHalvingYearStartTimestamp returns the start timestamp for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - timestamp: start timestamp for the year
func GetHalvingYearStartTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearEndTimestamp returns the end timestamp for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - timestamp: end timestamp for the year
func GetHalvingYearEndTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getEndTimestamp(year)
}

// GetHalvingYearMaxAmount returns the maximum token issuance for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - amount: maximum issuance amount for the year
func GetHalvingYearMaxAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMaxAmount(year)
}

// GetHalvingYearMintAmount returns the amount of tokens minted for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - amount: minted amount for the year
func GetHalvingYearMintAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMintedAmount(year)
}

// GetHalvingYearLeftAmount returns the remaining token issuance for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - amount: remaining issuance amount for the year
func GetHalvingYearLeftAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getLeftAmount(year)
}

// GetHalvingYearAccuAmount returns the accumulated token issuance for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - amount: accumulated issuance amount for the year
func GetHalvingYearAccuAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAccumAmount(year)
}

// GetAmountPerSecondPerHalvingYear returns the emission rate per second for the specified halving year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - amount: emission rate per second for the year
func GetAmountPerSecondPerHalvingYear(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAmountPerSecond(year)
}

// GetHalvingAmountsPerYear returns the total emission amount allocated for the specified year.
//
// Parameters:
//   - year: halving year (1-12)
//
// Returns:
//   - amount: allocated emission amount, or 0 if year is invalid
func GetHalvingAmountsPerYear(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return halvingAmountsPerYear[year-1]
}

// GetEmissionStartHeight returns the block height when emission schedule was initialized.
//
// Returns:
//   - height: emission start block height
func GetEmissionStartHeight() int64 {
	return getEmissionState().getCreatedHeight()
}

// GetEmissionStartTimestamp returns the timestamp when emission schedule begins.
//
// Returns:
//   - timestamp: emission start timestamp
func GetEmissionStartTimestamp() int64 {
	return getEmissionState().getStartTimestamp()
}

// GetEmissionEndTimestamp returns the timestamp when emission schedule ends.
//
// Returns:
//   - timestamp: emission end timestamp
func GetEmissionEndTimestamp() int64 {
	return getEmissionState().getEndTimestamp()
}

// GetHalvingYearInfo returns the halving year, start timestamp, and end timestamp for a given timestamp.
//
// Parameters:
//   - timestamp: timestamp to check
//
// Returns:
//   - year: halving year (1-12), or 0 if outside emission period
//   - startTimestamp: year start timestamp
//   - endTimestamp: year end timestamp
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

// GetHalvingInfo returns a clone of the halving data.
//
// Returns:
//   - halvingData: clone of halving data
func GetHalvingInfo() *HalvingData {
	return getEmissionState().getHalvingData().Clone()
}

// CalculateMintGnsAmount returns the amount of GNS that would be minted for the given timestamp range.
//
// Parameters:
//   - fromTimestamp: start timestamp
//   - toTimestamp: end timestamp
//
// Returns:
//   - amount: GNS amount that would be minted
func CalculateMintGnsAmount(fromTimestamp, toTimestamp int64) int64 {
	state := getEmissionState().Clone()

	amountToMint, err := calculateAmountToMint(state, fromTimestamp, toTimestamp)
	if err != nil {
		return 0
	}

	return amountToMint
}
