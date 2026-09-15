package gns

import (
	"time"

	gnsmath "gno.land/p/gnoswap/gnsmath/v1"
)

// GetMaxEmissionAmount returns the configured lifetime GNS emission cap in base units.
//
// Returns:
//   - maxAmount: maximum number of GNS base units available for emission
func GetMaxEmissionAmount() int64 {
	return MAX_EMISSION_AMOUNT
}

// GetMaximumSupply returns the maximum possible GNS token supply in base units.
//
// Returns:
//   - maximumSupply: configured total supply cap, including the initial mint and emissions
func GetMaximumSupply() int64 {
	return MAXIMUM_SUPPLY
}

// GetInitialMintAmount returns the initial GNS allocation minted before emissions.
//
// Returns:
//   - initialAmount: number of GNS base units in the initial mint
func GetInitialMintAmount() int64 {
	return INITIAL_MINT_AMOUNT
}

// IsEmissionInitialized reports whether the emission state has non-zero creation
// height and start timestamp.
//
// Returns:
//   - initialized: true when both initialization fields are set; false otherwise
func IsEmissionInitialized() bool {
	return getEmissionState().isInitialized()
}

// IsEmissionActive reports whether emission is initialized and the current Unix
// time lies within the inclusive emission schedule.
//
// Returns:
//   - active: true during the configured schedule, including its endpoints; false otherwise
func IsEmissionActive() bool {
	return getEmissionState().isActive(time.Now().Unix())
}

// IsEmissionEnded reports whether the current Unix time is after the emission end timestamp.
//
// Returns:
//   - ended: true after the configured schedule's end; false at or before that timestamp
func IsEmissionEnded() bool {
	return getEmissionState().isEnded(time.Now().Unix())
}

// GetHalvingYear returns the halving year containing timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to classify against the inclusive 12-year emission schedule
//
// Returns:
//   - year: halving year in [1, 12], or 0 when timestamp is before the start or after the end
func GetHalvingYear(timestamp int64) int64 {
	return getEmissionState().getCurrentYear(timestamp)
}

// GetCurrentYear returns the halving year containing the current Unix time.
//
// Returns:
//   - year: current halving year in [1, 12], or 0 when the current time is outside the schedule
func GetCurrentYear() int64 {
	return getEmissionState().getCurrentYear(time.Now().Unix())
}

// GetEmissionAmountPerSecondInRange returns paired emission-rate change points
// whose timestamps fall within the requested range.
//
// Parameters:
//   - fromTime: inclusive Unix timestamp lower bound
//   - toTime: inclusive Unix timestamp upper bound; a lower value yields nil slices
//
// Returns:
//   - timestamps: schedule timestamps in the range where the rate changes, including the post-end zero-rate point when applicable
//   - amounts: GNS base units emitted per second at each corresponding timestamp; same length and order as timestamps
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

// GetEmissionAmountPerSecondByTimestamp returns the configured GNS emission
// rate for the halving year containing timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp whose schedule rate is queried
//
// Returns:
//   - amount: GNS base units emitted per second for timestamp's halving year, or 0 outside the schedule
func GetEmissionAmountPerSecondByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearAmountPerSecond(year)
}

// GetEmissionLeftAmountByTimestamp returns the stored unminted allocation for
// the halving year containing timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp used to select a halving year
//
// Returns:
//   - amount: remaining GNS base units recorded for that halving year, or 0 outside the schedule
func GetEmissionLeftAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearLeftAmount(year)
}

// GetEmissionAccumulatedAmountByTimestamp returns the stored minted allocation
// for the halving year containing timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp used to select a halving year
//
// Returns:
//   - amount: minted GNS base units recorded for that halving year, or 0 outside the schedule
func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64 {
	state := getEmissionState()
	year := state.getCurrentYear(timestamp)
	return state.getHalvingYearMintedAmount(year)
}

// GetHalvingYearStartTimestamp returns the inclusive start Unix timestamp for
// a configured halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - timestamp: inclusive start timestamp for year, or 0 when year is invalid
func GetHalvingYearStartTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearEndTimestamp returns the inclusive end Unix timestamp for a
// configured halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - timestamp: inclusive end timestamp for year, or 0 when year is invalid
func GetHalvingYearEndTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getEndTimestamp(year)
}

// GetHalvingYearMaxAmount returns the maximum GNS allocation for a halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: maximum GNS base units allocated to year, or 0 when year is invalid
func GetHalvingYearMaxAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMaxAmount(year)
}

// GetHalvingYearLeftAmount returns the remaining GNS allocation recorded for a
// halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: unminted GNS base units for year, or 0 when year is invalid
func GetHalvingYearLeftAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getLeftAmount(year)
}

// GetHalvingYearMintedAmount returns the minted GNS allocation recorded for a
// halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: minted GNS base units for year, or 0 when year is invalid
func GetHalvingYearMintedAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMintedAmount(year)
}

// GetAmountPerSecondPerHalvingYear returns the configured GNS emission rate for
// a halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amountPerSecond: GNS base units emitted per second in year, or 0 when year is invalid
func GetAmountPerSecondPerHalvingYear(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAmountPerSecond(year)
}

// GetHalvingAmountsPerYear returns the total GNS allocation configured for a
// halving year.
//
// Parameters:
//   - year: halving year number in [1, 12]
//
// Returns:
//   - amount: total GNS base units allocated to year, or 0 when year is invalid
func GetHalvingAmountsPerYear(year int64) int64 {
	if validYear(year) != nil {
		return 0
	}
	return halvingAmountsPerYear[year-1]
}

// GetEmissionCreatedHeight returns the blockchain height recorded when the
// emission schedule was created.
//
// Returns:
//   - height: schedule creation height, or the uninitialized state's stored value
func GetEmissionCreatedHeight() int64 {
	return getEmissionState().getCreatedHeight()
}

// GetEmissionStartTimestamp returns the inclusive Unix timestamp at which the
// configured emission schedule begins.
//
// Returns:
//   - timestamp: schedule start timestamp
func GetEmissionStartTimestamp() int64 {
	return getEmissionState().getStartTimestamp()
}

// GetEmissionEndTimestamp returns the inclusive Unix timestamp at which the
// configured emission schedule ends.
//
// Returns:
//   - timestamp: schedule end timestamp
func GetEmissionEndTimestamp() int64 {
	return getEmissionState().getEndTimestamp()
}

// GetHalvingYearInfo returns the configured halving interval containing timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to classify against the inclusive emission schedule
//
// Returns:
//   - year: halving year in [1, 12], or 0 outside the schedule
//   - startTimestamp: inclusive start timestamp of year, or 0 when timestamp is outside the schedule
//   - endTimestamp: inclusive end timestamp of year, or 0 when timestamp is outside the schedule
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

// GetHalvingInfo returns an independent copy of the configured 12-year halving schedule.
//
// Returns:
//   - halvingData: deep copy of schedule timestamps, allocations, minted amounts, remaining amounts, and rates
func GetHalvingInfo() *HalvingData {
	return getEmissionState().getHalvingData().Clone()
}

// CalculateMintGnsAmount calculates the GNS base units allocated over an
// inclusive timestamp range without mutating the live emission state.
//
// Parameters:
//   - fromTimestamp: inclusive Unix timestamp at which allocation begins
//   - toTimestamp: inclusive Unix timestamp at which allocation ends
//
// Returns:
//   - amount: GNS base units allocated in the overlapping schedule interval, or 0 for an invalid or non-overlapping range
func CalculateMintGnsAmount(fromTimestamp, toTimestamp int64) int64 {
	state := getEmissionState().Clone()

	amountToMint, err := calculateAmountToMint(state, fromTimestamp, toTimestamp)
	if err != nil {
		return 0
	}

	return amountToMint
}
