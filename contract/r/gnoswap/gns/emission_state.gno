package gns

import (
	"std"
	"time"

	"gno.land/p/nt/ufmt"
)

var emissionState *EmissionState

func init() {
	emissionState = NewEmissionState(0, 0)
}

// EmissionState manages emission state and halving data.
// Tracks emission timing, status, and halving year information for 12-year schedule.
type EmissionState struct {
	startHeight    int64
	startTimestamp int64
	endTimestamp   int64
	halvingData    *HalvingData
}

// isInitialized returns true if emission state has been initialized with valid height and timestamp.
func (e *EmissionState) isInitialized() bool {
	return e.startHeight != 0 && e.startTimestamp != 0
}

// isActive returns true if emission is currently active at the given timestamp.
// Returns false if not initialized or timestamp is outside emission period.
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

// isEnded returns true if emission has ended at the given timestamp.
func (e *EmissionState) isEnded(timestamp int64) bool {
	return e.endTimestamp < timestamp
}

// getCurrentYear returns the halving year (1-12) for the given timestamp, or 0 if outside emission period.
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

// getStartHeight returns the blockchain height when emission started.
func (e *EmissionState) getStartHeight() int64 {
	return e.startHeight
}

// getStartTimestamp returns the timestamp when emission started.
func (e *EmissionState) getStartTimestamp() int64 {
	return e.startTimestamp
}

// getEndTimestamp returns the timestamp when emission ends.
func (e *EmissionState) getEndTimestamp() int64 {
	return e.endTimestamp
}

// getHalvingData returns the halving data containing emission schedule details.
func (e *EmissionState) getHalvingData() *HalvingData {
	return e.halvingData
}

// getHalvingYearStartTimestamp returns the start timestamp for the specified halving year.
func (e *EmissionState) getHalvingYearStartTimestamp(year int64) int64 {
	return e.halvingData.getStartTimestamp(year)
}

// getHalvingYearEndTimestamp returns the end timestamp for the specified halving year.
func (e *EmissionState) getHalvingYearEndTimestamp(year int64) int64 {
	return e.halvingData.getEndTimestamp(year)
}

// getHalvingYearAmountPerSecond returns the emission rate per second for the specified halving year.
func (e *EmissionState) getHalvingYearAmountPerSecond(year int64) int64 {
	return e.halvingData.getAmountPerSecond(year)
}

// getHalvingYearAccumulatedAmount returns the accumulated emission amount for the specified halving year.
func (e *EmissionState) getHalvingYearAccumulatedAmount(year int64) int64 {
	return e.halvingData.getAccumAmount(year)
}

// getHalvingYearLeftAmount returns the remaining emission amount for the specified halving year.
func (e *EmissionState) getHalvingYearLeftAmount(year int64) int64 {
	return e.halvingData.getLeftAmount(year)
}

// addHalvingYearAccumulatedAmount adds to the accumulated emission amount for the specified halving year.
// Returns error if year is invalid (0 or outside 1-12 range).
func (e *EmissionState) addHalvingYearAccumulatedAmount(year int64, amount int64) error {
	if year == 0 {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	accumulatedAmount := e.halvingData.getAccumAmount(year)
	accumulatedAmount += amount

	e.halvingData.setAccumAmount(year, accumulatedAmount)
	return nil
}

// subHalvingYearLeftAmount subtracts from the remaining emission amount for the specified halving year.
// Returns error if year is invalid (0 or outside 1-12 range).
func (e *EmissionState) subHalvingYearLeftAmount(year int64, amount int64) error {
	if year == 0 {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	leftAmount := e.halvingData.getLeftAmount(year)
	leftAmount -= amount

	e.halvingData.setLeftAmount(year, leftAmount)
	return nil
}

// updateHalvingData initializes halving data with the given start timestamp.
func (e *EmissionState) updateHalvingData(startTimestamp int64) {
	e.halvingData = NewHalvingData(startTimestamp)
}

// NewEmissionState creates a new EmissionState with specified start height and timestamp.
// Calculates emission end time based on 12-year schedule and initializes halving data.
func NewEmissionState(startHeight int64, startTimestamp int64) *EmissionState {
	emissionEndTime := startTimestamp + SECONDS_IN_YEAR*HALVING_END_YEAR - 1

	return &EmissionState{
		startHeight:    startHeight,
		startTimestamp: startTimestamp,
		endTimestamp:   emissionEndTime,
		halvingData:    NewHalvingData(startTimestamp),
	}
}

// getEmissionState returns the singleton emission state instance.
// Creates a new instance with current height and timestamp if one doesn't exist.
func getEmissionState() *EmissionState {
	if emissionState == nil {
		emissionState = NewEmissionState(std.ChainHeight(), time.Now().Unix())
	}

	return emissionState
}
