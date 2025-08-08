package gns

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
)

var emissionState *EmissionState

func init() {
	emissionState = NewEmissionState(0, 0)
}

// EmissionState manages emission state and halving data.
type EmissionState struct {
	startHeight    int64
	startTimestamp int64
	endTimestamp   int64
	halvingData    *HalvingData
}

func (e *EmissionState) isInitialized() bool {
	return e.startHeight != 0 && e.startTimestamp != 0
}

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

func (e *EmissionState) isEnded(timestamp int64) bool {
	return e.endTimestamp < timestamp
}

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

func (e *EmissionState) getStartHeight() int64 {
	return e.startHeight
}

func (e *EmissionState) getStartTimestamp() int64 {
	return e.startTimestamp
}

func (e *EmissionState) getEndTimestamp() int64 {
	return e.endTimestamp
}

func (e *EmissionState) getHalvingData() *HalvingData {
	return e.halvingData
}

func (e *EmissionState) getHalvingYearStartTimestamp(year int64) int64 {
	return e.halvingData.getStartTimestamp(year)
}

func (e *EmissionState) getHalvingYearEndTimestamp(year int64) int64 {
	return e.halvingData.getEndTimestamp(year)
}

func (e *EmissionState) getHalvingYearAmountPerSecond(year int64) int64 {
	return e.halvingData.getAmountPerSecond(year)
}

func (e *EmissionState) getHalvingYearAccumulatedAmount(year int64) int64 {
	return e.halvingData.getAccumAmount(year)
}

func (e *EmissionState) getHalvingYearLeftAmount(year int64) int64 {
	return e.halvingData.getLeftAmount(year)
}

// addHalvingYearAccumulatedAmount adds to accumulated amount for halving year.
func (e *EmissionState) addHalvingYearAccumulatedAmount(year int64, amount int64) error {
	if year == 0 {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	accumulatedAmount := e.halvingData.getAccumAmount(year)
	accumulatedAmount += amount

	e.halvingData.setAccumAmount(year, accumulatedAmount)
	return nil
}

// subHalvingYearLeftAmount subtracts from remaining amount for halving year.
func (e *EmissionState) subHalvingYearLeftAmount(year int64, amount int64) error {
	if year == 0 {
		return makeErrorWithDetails(errInvalidYear, ufmt.Sprintf("year: %d", year))
	}

	leftAmount := e.halvingData.getLeftAmount(year)
	leftAmount -= amount

	e.halvingData.setLeftAmount(year, leftAmount)
	return nil
}

// updateHalvingData initializes halving data.
func (e *EmissionState) updateHalvingData(startTimestamp int64) {
	e.halvingData = NewHalvingData(startTimestamp)
}

// NewEmissionState creates new emission state.
func NewEmissionState(startHeight int64, startTimestamp int64) *EmissionState {
	emissionEndTime := startTimestamp + SECONDS_IN_YEAR*HALVING_END_YEAR - 1

	return &EmissionState{
		startHeight:    startHeight,
		startTimestamp: startTimestamp,
		endTimestamp:   emissionEndTime,
		halvingData:    NewHalvingData(startTimestamp),
	}
}

// getEmissionState returns singleton emission state.
func getEmissionState() *EmissionState {
	if emissionState == nil {
		emissionState = NewEmissionState(std.ChainHeight(), time.Now().Unix())
	}

	return emissionState
}
