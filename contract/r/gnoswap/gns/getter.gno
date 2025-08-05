package gns

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/json"
)

// IsEmissionInitialized checks if the emission schedule has been initialized.
//
// Returns:
//   - bool: true if emission state is initialized, false otherwise
//
func IsEmissionInitialized() bool {
	return getEmissionState().isInitialized()
}

// IsEmissionActive checks if emission is currently active.
//
// Emission is active when the current time is between the start and end
// timestamps of the emission schedule.
//
// Returns:
//   - bool: true if emissions are currently being distributed, false otherwise
//
func IsEmissionActive() bool {
	return getEmissionState().isActive(time.Now().Unix())
}

// IsEmissionEnded checks if the emission schedule has completed.
//
// Returns:
//   - bool: true if all emission periods have ended, false otherwise
//
func IsEmissionEnded() bool {
	return getEmissionState().isEnded(time.Now().Unix())
}

func GetHalvingYear(timestamp int64) int64 {
	return getEmissionState().getCurrentYear(timestamp)
}

// GetCurrentYear returns the current halving year in the emission schedule.
//
// Years range from 1 to 13, with each year lasting 4 calendar years.
// Returns 0 if emission hasn't started or has ended.
//
// Returns:
//   - int64: Current halving year (1-13) or 0 if not active
//
func GetCurrentYear() int64 {
	return getEmissionState().getCurrentYear(time.Now().Unix())
}

// GetEmissionAmountPerSecondsInRange returns halving timestamps and emission rates within a time range.
//
// This function provides the emission schedule data for a specified time period,
// useful for calculating expected emissions or displaying emission curves.
//
// Parameters:
//   - fromTime: Start timestamp (inclusive)
//   - toTime: End timestamp (inclusive)
//
// Returns:
//   - []int64: Array of timestamps when emission rate changes
//   - []int64: Array of emission amounts per second for each period
//
// Example:
//   times, rates := GetEmissionAmountPerSecondsInRange(startTime, endTime)
//   // times[0] = 1234567890 (start of year 2)
//   // rates[0] = 7127566 (GNS per second in year 2)
//
func GetEmissionAmountPerSecondsInRange(fromTime, toTime int64) ([]int64, []int64) {
	halvingData := getEmissionState().getHalvingData()
	halvingTimes := make([]int64, 0)
	halvingEmissions := make([]int64, 0)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		startTimestamp := halvingData.getStartTimestamp(year)
		if startTimestamp < fromTime {
			continue
		}
		
		if toTime < startTimestamp {
			break
		}

		halvingTimes = append(halvingTimes, startTimestamp)
		halvingEmissions = append(halvingEmissions, halvingData.getAmountPerSeconds(year))
	}

	return halvingTimes, halvingEmissions
}

func GetEmissionAmountPerSecondsByTimestamp(timestamp int64) int64 {
	year := getEmissionState().getCurrentYear(timestamp)
	return getEmissionState().getHalvingYearAmountPerSeconds(year)
}

func GetEmissionLeftAmountByTimestamp(timestamp int64) int64 {
	year := getEmissionState().getCurrentYear(timestamp)
	return getEmissionState().getHalvingYearLeftAmount(year)
}

func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64 {
	year := getEmissionState().getCurrentYear(timestamp)
	return getEmissionState().getHalvingYearAccumulatedAmount(year)
}

// GetHalvingYearStartTimestamp returns the starting timestamp for a specific halving year
func GetHalvingYearStartTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearEndTimestamp returns the ending timestamp for a specific halving year
func GetHalvingYearEndTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getEndTimestamp(year)
}

// GetHalvingYearTimestamp returns the starting timestamp for a specific halving year
func GetHalvingYearTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearMaxAmount returns the maximum issuance amount for a specific halving year
func GetHalvingYearMaxAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMaxAmount(year)
}

// GetHalvingYearMintAmount returns the minted amount for a specific halving year
func GetHalvingYearMintAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMintedAmount(year)
}

// GetHalvingYearLeftAmount returns the remaining issuance amount for a specific halving year
func GetHalvingYearLeftAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getLeftAmount(year)
}

// GetHalvingYearAccuAmount returns the accumulated issuance amount for a specific halving year
func GetHalvingYearAccuAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAccumAmount(year)
}

// GetAmountPerSecondsPerHalvingYear returns the issuance amount per second for a specific halving year
func GetAmountPerSecondsPerHalvingYear(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAmountPerSeconds(year)
}

// GetHalvingAmountsPerYear returns the halving amount for a specific year
func GetHalvingAmountsPerYear(year int64) int64 {
	return halvingAmountsPerYear[year-1]
}

// GetEmissionStartTimestamp returns the start timestamp of the emission period
func GetEmissionStartTimestamp() int64 {
	return getEmissionState().getStartTimestamp()
}

// GetEmissionEndTimestamp returns the end timestamp of the emission period
func GetEmissionEndTimestamp() int64 {
	return getEmissionState().getEndTimestamp()
}

// GetHalvingYearInfo returns the halving year and start timestamp corresponding to the given timestamp
func GetHalvingYearInfo(timestamp int64) (int64, int64, int64) {
	state := getEmissionState()

	endTimestamp := state.getEndTimestamp()
	startTimestamp := state.getStartTimestamp()

	year := getEmissionState().getCurrentYear(timestamp)

	return year, startTimestamp + (SECONDS_IN_YEAR * year), endTimestamp
}

// GetHalvingInfo returns the halving information in JSON format
func GetHalvingInfo() string {
	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()

	halvings := make([]*json.Node, 0)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		halvings = append(halvings, json.ObjectNode("", map[string]*json.Node{
			"year":   json.StringNode("year", strconv.FormatInt(year, 10)),
			"timestamp": json.NumberNode("timestamp", float64(GetHalvingYearTimestamp(year))),
			"amount": json.NumberNode("amount", float64(GetAmountPerSecondsPerHalvingYear(year))),
		}))
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"height":         json.NumberNode("height", float64(currentHeight)),
		"currentTime":      json.NumberNode("timestamp", float64(currentTime)),
		"halvings":       json.ArrayNode("", halvings),
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}