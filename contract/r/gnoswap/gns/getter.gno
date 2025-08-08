package gns

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/json"
)

// IsEmissionInitialized checks if emission schedule is initialized.
func IsEmissionInitialized() bool {
	return getEmissionState().isInitialized()
}

// IsEmissionActive checks if emission is currently active.
func IsEmissionActive() bool {
	return getEmissionState().isActive(time.Now().Unix())
}

// IsEmissionEnded checks if emission schedule has completed.
func IsEmissionEnded() bool {
	return getEmissionState().isEnded(time.Now().Unix())
}

func GetHalvingYear(timestamp int64) int64 {
	return getEmissionState().getCurrentYear(timestamp)
}

// GetCurrentYear returns current halving year (1-12) or 0 if not active.
func GetCurrentYear() int64 {
	return getEmissionState().getCurrentYear(time.Now().Unix())
}

// GetEmissionAmountPerSecondInRange returns halving timestamps and emission rates within time range.
func GetEmissionAmountPerSecondInRange(fromTime, toTime int64) ([]int64, []int64) {
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
		halvingEmissions = append(halvingEmissions, halvingData.getAmountPerSecond(year))
	}

	return halvingTimes, halvingEmissions
}

func GetEmissionAmountPerSecondByTimestamp(timestamp int64) int64 {
	year := getEmissionState().getCurrentYear(timestamp)
	return getEmissionState().getHalvingYearAmountPerSecond(year)
}

func GetEmissionLeftAmountByTimestamp(timestamp int64) int64 {
	year := getEmissionState().getCurrentYear(timestamp)
	return getEmissionState().getHalvingYearLeftAmount(year)
}

func GetEmissionAccumulatedAmountByTimestamp(timestamp int64) int64 {
	year := getEmissionState().getCurrentYear(timestamp)
	return getEmissionState().getHalvingYearAccumulatedAmount(year)
}

// GetHalvingYearStartTimestamp returns start timestamp for halving year.
func GetHalvingYearStartTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearEndTimestamp returns end timestamp for halving year.
func GetHalvingYearEndTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getEndTimestamp(year)
}

// GetHalvingYearTimestamp returns start timestamp for halving year.
func GetHalvingYearTimestamp(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getStartTimestamp(year)
}

// GetHalvingYearMaxAmount returns max issuance for halving year.
func GetHalvingYearMaxAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMaxAmount(year)
}

// GetHalvingYearMintAmount returns minted amount for halving year.
func GetHalvingYearMintAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getMintedAmount(year)
}

// GetHalvingYearLeftAmount returns remaining issuance for halving year.
func GetHalvingYearLeftAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getLeftAmount(year)
}

// GetHalvingYearAccuAmount returns accumulated issuance for halving year.
func GetHalvingYearAccuAmount(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAccumAmount(year)
}

// GetAmountPerSecondPerHalvingYear returns emission rate per second for halving year.
func GetAmountPerSecondPerHalvingYear(year int64) int64 {
	halvingData := getEmissionState().getHalvingData()
	return halvingData.getAmountPerSecond(year)
}

// GetHalvingAmountsPerYear returns total emission amount for specific year.
func GetHalvingAmountsPerYear(year int64) int64 {
	return halvingAmountsPerYear[year-1]
}

// GetEmissionStartTimestamp returns emission start timestamp.
func GetEmissionStartTimestamp() int64 {
	return getEmissionState().getStartTimestamp()
}

// GetEmissionEndTimestamp returns emission end timestamp.
func GetEmissionEndTimestamp() int64 {
	return getEmissionState().getEndTimestamp()
}

// GetHalvingYearInfo returns halving year and timestamps for given timestamp.
func GetHalvingYearInfo(timestamp int64) (int64, int64, int64) {
	state := getEmissionState()

	endTimestamp := state.getEndTimestamp()
	startTimestamp := state.getStartTimestamp()

	year := getEmissionState().getCurrentYear(timestamp)

	return year, startTimestamp + (SECONDS_IN_YEAR * year), endTimestamp
}

// GetHalvingInfo returns halving information as JSON.
func GetHalvingInfo() string {
	currentTime := time.Now().Unix()
	currentHeight := std.ChainHeight()

	halvings := make([]*json.Node, 0)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		halvings = append(halvings, json.ObjectNode("", map[string]*json.Node{
			"year":      json.StringNode("year", strconv.FormatInt(year, 10)),
			"timestamp": json.NumberNode("timestamp", float64(GetHalvingYearTimestamp(year))),
			"amount":    json.NumberNode("amount", float64(GetAmountPerSecondPerHalvingYear(year))),
		}))
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"height":      json.NumberNode("height", float64(currentHeight)),
		"currentTime": json.NumberNode("timestamp", float64(currentTime)),
		"halvings":    json.ArrayNode("", halvings),
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}
