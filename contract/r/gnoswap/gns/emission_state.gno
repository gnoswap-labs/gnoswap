package gns

import (
	"chain/runtime"
	"time"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	ufmt "gno.land/p/nt/ufmt/v0"
)

var emissionState *EmissionState

// init initializes the package emission state with an unstarted schedule.
func init() {
	emissionState = NewEmissionState(0, 0)
}

// EmissionState manages emission state and halving data.
// Tracks emission timing, status, and halving year information for 12-year schedule.
type EmissionState struct {
	createdHeight  int64
	startTimestamp int64
	endTimestamp   int64
	halvingData    *HalvingData
}

// isInitialized reports whether both the creation height and start timestamp
// have been set to nonzero values.
//
// Returns:
//   - initialized: true when the state has nonzero creation height and start timestamp.
func (e *EmissionState) isInitialized() bool {
	return e.createdHeight != 0 && e.startTimestamp != 0
}

// isActive reports whether emission is active at a given Unix timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to test against the inclusive emission interval.
//
// Returns:
//   - active: true only when the schedule is initialized and startTimestamp <= timestamp <= endTimestamp.
func (e *EmissionState) isActive(timestamp int64) bool {
	if !e.isInitialized() {
		return false
	}

	if e.startTimestamp > timestamp {
		return false
	}

	if e.endTimestamp < timestamp {
		return false
	}

	return true
}

// isEnded reports whether the configured emission end has passed.
//
// Parameters:
//   - timestamp: Unix timestamp to compare with the configured end timestamp.
//
// Returns:
//   - ended: true when timestamp is strictly after endTimestamp; false at or before the end.
func (e *EmissionState) isEnded(timestamp int64) bool {
	return e.endTimestamp < timestamp
}

// getCurrentYear returns the halving year containing a Unix timestamp.
//
// Parameters:
//   - timestamp: Unix timestamp to map to the emission schedule.
//
// Returns:
//   - year: halving year from 1 through 12, or 0 when timestamp is outside the schedule.
func (e *EmissionState) getCurrentYear(timestamp int64) int64 {
	if timestamp < e.startTimestamp {
		return 0
	}

	if timestamp > e.endTimestamp {
		return 0
	}

	year := (timestamp - e.startTimestamp) / SECONDS_IN_YEAR
	return year + 1
}

// getCreatedHeight returns the blockchain height recorded when emission was initialized.
//
// Returns:
//   - height: stored creation block height for the emission schedule.
func (e *EmissionState) getCreatedHeight() int64 {
	return e.createdHeight
}

// getStartTimestamp returns the Unix timestamp at which emission begins.
//
// Returns:
//   - timestamp: stored emission start time in Unix seconds.
func (e *EmissionState) getStartTimestamp() int64 {
	return e.startTimestamp
}

// getEndTimestamp returns the inclusive Unix timestamp at which emission ends.
//
// Returns:
//   - timestamp: stored emission end time in Unix seconds.
func (e *EmissionState) getEndTimestamp() int64 {
	return e.endTimestamp
}

// getHalvingData returns the state-owned halving schedule data.
//
// Returns:
//   - halvingData: pointer to the schedule's per-year timestamps, amounts, and rates.
func (e *EmissionState) getHalvingData() *HalvingData {
	return e.halvingData
}

// getHalvingYearStartTimestamp returns the start timestamp for a halving year.
//
// Parameters:
//   - year: halving year to query; valid values are 1 through 12.
//
// Returns:
//   - timestamp: Unix start timestamp for year, or 0 when year is invalid.
func (e *EmissionState) getHalvingYearStartTimestamp(year int64) int64 {
	return e.halvingData.getStartTimestamp(year)
}

// getHalvingYearEndTimestamp returns the end timestamp for a halving year.
//
// Parameters:
//   - year: halving year to query; valid values are 1 through 12.
//
// Returns:
//   - timestamp: Unix end timestamp for year, or 0 when year is invalid.
func (e *EmissionState) getHalvingYearEndTimestamp(year int64) int64 {
	return e.halvingData.getEndTimestamp(year)
}

// getHalvingYearAmountPerSecond returns the configured emission rate for a halving year.
//
// Parameters:
//   - year: halving year to query; valid values are 1 through 12.
//
// Returns:
//   - amountPerSecond: GNS emission rate for year in token base units per second, or 0 when year is invalid.
func (e *EmissionState) getHalvingYearAmountPerSecond(year int64) int64 {
	return e.halvingData.getAmountPerSecond(year)
}

// getHalvingYearMintedAmount returns the amount already minted in a halving year.
//
// Parameters:
//   - year: halving year to query; valid values are 1 through 12.
//
// Returns:
//   - mintedAmount: GNS amount minted for year in token base units, or 0 when year is invalid.
func (e *EmissionState) getHalvingYearMintedAmount(year int64) int64 {
	return e.halvingData.getMintedAmount(year)
}

// getHalvingYearLeftAmount returns the amount remaining to mint in a halving year.
//
// Parameters:
//   - year: halving year to query; valid values are 1 through 12.
//
// Returns:
//   - leftAmount: remaining GNS allocation for year in token base units, or 0 when year is invalid.
func (e *EmissionState) getHalvingYearLeftAmount(year int64) int64 {
	return e.halvingData.getLeftAmount(year)
}

// addHalvingYearMintedAmount adds an amount to a halving year's minted total.
//
// Parameters:
//   - year: halving year to update; valid values are 1 through 12.
//   - amount: GNS amount to add to the year's minted total, in token base units.
//
// Returns:
//   - error: nil when the year is updated; otherwise errInvalidYear for a year outside 1 through 12.
func (e *EmissionState) addHalvingYearMintedAmount(year int64, amount int64) error {
	if year == 0 {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	mintedAmount := e.halvingData.getMintedAmount(year)
	mintedAmount = gnsmath.SafeAddInt64(mintedAmount, amount)

	return e.halvingData.setMintedAmount(year, mintedAmount)
}

// subHalvingYearLeftAmount subtracts an amount from a halving year's remaining allocation.
//
// Parameters:
//   - year: halving year to update; valid values are 1 through 12.
//   - amount: GNS amount to subtract from the year's remaining total, in token base units.
//
// Returns:
//   - error: nil when the year is updated; otherwise errInvalidYear for a year outside 1 through 12.
func (e *EmissionState) subHalvingYearLeftAmount(year int64, amount int64) error {
	if year == 0 {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	leftAmount := e.halvingData.getLeftAmount(year)
	leftAmount = gnsmath.SafeSubInt64(leftAmount, amount)

	return e.halvingData.setLeftAmount(year, leftAmount)
}

// Clone returns a deep copy of the emission state, including independent halving data.
//
// Returns:
//   - clone: independent EmissionState copy with the same schedule values.
func (e *EmissionState) Clone() *EmissionState {
	return &EmissionState{
		createdHeight:  e.createdHeight,
		startTimestamp: e.startTimestamp,
		endTimestamp:   e.endTimestamp,
		halvingData:    e.halvingData.Clone(),
	}
}

// NewEmissionState creates an emission state and its 12-year halving schedule.
//
// Parameters:
//   - createdHeight: blockchain height recorded as the schedule's creation height.
//   - startTimestamp: Unix timestamp at which the first halving year begins.
//
// Returns:
//   - state: newly allocated emission state with an end timestamp and initialized halving data.
func NewEmissionState(createdHeight int64, startTimestamp int64) *EmissionState {
	emissionEndTime := gnsmath.SafeAddInt64(startTimestamp, SECONDS_IN_YEAR*HALVING_END_YEAR-1)

	return &EmissionState{
		createdHeight:  createdHeight,
		startTimestamp: startTimestamp,
		endTimestamp:   emissionEndTime,
		halvingData:    NewHalvingData(startTimestamp),
	}
}

// getEmissionState returns the package's singleton emission state.
// If the singleton is nil, it lazily initializes one from the current chain height and time.
//
// Returns:
//   - state: shared emission state pointer used by package getters and updates.
func getEmissionState() *EmissionState {
	if emissionState == nil {
		emissionState = NewEmissionState(runtime.ChainHeight(), time.Now().Unix())
	}

	return emissionState
}
