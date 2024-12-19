package gns

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/p/demo/json"
)

// init 12 years halving tier block
/*
	NOTE: assume block will be created every 1 second by default
	1 second = 1 block
	1 minute = 60 block
	1 hour = 3600 block
	1 day = 86400 block
	(365 days) 1 year = 31536000 block
*/

const (
	HALVING_START_YEAR = int64(1)
	HALVING_END_YEAR   = int64(12)

	HALVING_AMOUNTS_PER_YEAR = [12]uint64{
		18_750_000_000_000 * 12, // Year 1:  225000000000000
		18_750_000_000_000 * 12, // Year 2:  225000000000000
		9_375_000_000_000 * 12,  // Year 3:  112500000000000
		9_375_000_000_000 * 12,  // Year 4:  112500000000000
		4_687_500_000_000 * 12,  // Year 5:  56250000000000
		4_687_500_000_000 * 12,  // Year 6:  56250000000000
		2_343_750_000_000 * 12,  // Year 7:  28125000000000
		2_343_750_000_000 * 12,  // Year 8:  28125000000000
		1_171_875_000_000 * 12,  // Year 9:  14062500000000
		1_171_875_000_000 * 12,  // Year 10: 14062500000000
		1_171_875_000_000 * 12,  // Year 11: 14062500000000
		1_171_875_000_000 * 12,  // Year 12: 14062500000000
	}
)

var (
	BLOCK_PER_YEAR = consts.TIMESTAMP_YEAR / consts.BLOCK_GENERATION_INTERVAL
	BLOCK_PER_DAY  = consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL

	avgBlockTimeMs int64 = consts.SECOND_IN_MILLISECOND * consts.BLOCK_GENERATION_INTERVAL
)

var (
	startHeight    int64
	startTimestamp int64

	// (exactly) after 12 years, timestamp which gns emission will be ended
	// can not be changed
	endTimestamp int64
)

var (
	halvingYearBlock     = make([]int64, HALVING_END_YEAR) // start block of each halving year
	halvingYearTimestamp = make([]int64, HALVING_END_YEAR) // start timestamp of each halving year

	halvingYearMaxAmount         = make([]uint64, HALVING_END_YEAR)
	halvingYearMintAmount        = make([]uint64, HALVING_END_YEAR)
	halvingYearAccuAmount        = make([]uint64, HALVING_END_YEAR)
	amountPerBlockPerHalvingYear = make([]uint64, HALVING_END_YEAR)
)

func init() {
	startHeight = std.GetHeight()
	startTimestamp = time.Now().Unix()

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		setHalvingYearMaxAmount(year, HALVING_AMOUNTS_PER_YEAR[year-1])

		if year == 1 {
			setHalvingYearAccuAmount(year, HALVING_AMOUNTS_PER_YEAR[year-1])
		} else {
			setHalvingYearAccuAmount(year, GetHalvingYearAccuAmount(year-1)+HALVING_AMOUNTS_PER_YEAR[year-1])
		}

		setHalvingYearBlock(year, startHeight+BLOCK_PER_YEAR*(year-1))
		setHalvingYearTimestamp(year, startTimestamp+(consts.TIMESTAMP_YEAR*(year-1)))
		setHalvingYearMintAmount(year, uint64(0))

		amountPerYear := GetHalvingYearMaxAmount(year)         // amount per year
		amountPerDay := amountPerYear / consts.DAY_PER_YEAR    // amount per day
		amountPerBlock := amountPerDay / uint64(BLOCK_PER_DAY) // amount per block
		setAmountPerBlockPerHalvingYear(year, uint64(amountPerBlock))
	}

	setEndTimestamp(startTimestamp + consts.TIMESTAMP_YEAR*HALVING_END_YEAR)
}

func GetAvgBlockTimeInMs() int64 {
	return avgBlockTimeMs
}

// SetAvgBlockTimeInMsByAdmin sets the average block time in millisecond.
func SetAvgBlockTimeInMsByAdmin(ms int64) {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}

	setAvgBlockTimeInMs(ms)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetAvgBlockTimeInMsByAdmin",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"ms", ufmt.Sprintf("%d", ms),
	)
}

// SetAvgBlockTimeInMs sets the average block time in millisecond.
// Only governance contract can execute this function via proposal
func SetAvgBlockTimeInMs(ms int64) {
	caller := std.PrevRealm().Addr()
	if err := common.GovernanceOnly(caller); err != nil {
		panic(err)
	}

	setAvgBlockTimeInMs(ms)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"SetAvgBlockTimeInMs",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"ms", ufmt.Sprintf("%d", ms),
	)
}

func setAvgBlockTimeInMs(ms int64) {
	common.IsHalted()

	now := time.Now().Unix()
	height := std.GetHeight()

	// get the halving year and end timestamp of current time
	currentYear, endTimestamp := getHalvingYearAndEndTimestamp(now)

	// how much time left for current halving year
	timeLeft := endTimestamp - now
	timeLeftMs := timeLeft * consts.SECOND_IN_MILLISECOND

	// how many block left for current halving year
	blockLeft := timeLeftMs / ms

	// how many reward left for current halving year
	minted := GetMintedEmissionAmount()
	amountLeft := GetHalvingYearAccuAmount(currentYear) - minted

	// how much reward should be minted per block for current halving year
	adjustedAmountPerBlock := amountLeft / uint64(blockLeft)
	setAmountPerBlockPerHalvingYear(currentYear, adjustedAmountPerBlock)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		if year < currentYear {
			// pass past halving years
			continue
		}

		yearEndTimestamp := GetHalvingYearTimestamp(year) + consts.TIMESTAMP_YEAR
		timeLeftForYear := yearEndTimestamp - now
		numBlock := (timeLeftForYear * consts.SECOND_IN_MILLISECOND) / ms
		setHalvingYearBlock(year, height+numBlock)
	}

	avgBlockTimeMs = ms
}

// GetAmountByHeight returns the amount of gns to mint by height
func GetAmountByHeight(height int64) uint64 {
	if isEmissionEnded(height) {
		return 0
	}

	halvingYear := GetHalvingYearByHeight(height)
	return GetAmountPerBlockPerHalvingYear(halvingYear)
}

// GetHalvingYearByHeight returns the halving year by height
func GetHalvingYearByHeight(height int64) int64 {
	if isEmissionEnded(height) {
		return 0
	}

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		block := GetHalvingYearBlock(year)
		if height <= block {
			return year
		}
	}

	return 0
}

// getHalvingYearAndEndTimestamp returns the halving year and end timestamp of the given timestamp
// if the timestamp is not in any halving year, it returns 0, 0
func getHalvingYearAndEndTimestamp(timestamp int64) (int64, int64) {
	if timestamp > endTimestamp { // after 12 years
		return 0, 0
	}

	timestamp -= startTimestamp

	year := timestamp / consts.TIMESTAMP_YEAR
	year += 1 // since we subtract startTimestamp at line 215, we need to add 1 to get the correct year

	return year, startTimestamp + (consts.TIMESTAMP_YEAR * year)
}

func GetHalvingYearBlock(year int64) int64 {
	return halvingYearBlock[year-1]
}

func setHalvingYearBlock(year int64, block int64) {
	halvingYearBlock[year-1] = block
}

func GetHalvingYearTimestamp(year int64) int64 {
	return halvingYearTimestamp[year-1]
}

func setHalvingYearTimestamp(year int64, timestamp int64) {
	halvingYearTimestamp[year-1] = timestamp
}

func GetHalvingYearMaxAmount(year int64) uint64 {
	return halvingYearMaxAmount[year-1]
}

func setHalvingYearMaxAmount(year int64, amount uint64) {
	halvingYearMaxAmount[year-1] = amount
}

func GetHalvingYearMintAmount(year int64) uint64 {
	return halvingYearMintAmount[year-1]
}

func setHalvingYearMintAmount(year int64, amount uint64) {
	halvingYearMintAmount[year-1] = amount
}

func GetHalvingYearAccuAmount(year int64) uint64 {
	return halvingYearAccuAmount[year-1]
}

func setHalvingYearAccuAmount(year int64, amount uint64) {
	halvingYearAccuAmount[year-1] = amount
}

func GetAmountPerBlockPerHalvingYear(year int64) uint64 {
	return amountPerBlockPerHalvingYear[year-1]
}

func setAmountPerBlockPerHalvingYear(year int64, amount uint64) {
	amountPerBlockPerHalvingYear[year-1] = amount
}

func GetEndHeight() int64 {
	// last block of last halving year(12) is last block of emission
	// later than this block, no more gns will be minted
	return GetHalvingYearBlock(HALVING_END_YEAR)
}

func GetEndTimestamp() int64 {
	return endTimestamp
}

func setEndTimestamp(timestamp int64) {
	endTimestamp = timestamp
}

func GetHalvingInfo() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	halvings := make([]*json.Node, 0)

	for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
		halvings = append(halvings, json.ObjectNode("", map[string]*json.Node{
			"year":   json.StringNode("year", strconv.FormatInt(year, 10)),
			"block":  json.NumberNode("block", float64(GetHalvingYearBlock(year))),
			"amount": json.NumberNode("amount", float64(GetAmountPerBlockPerHalvingYear(year))),
		}))
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"height":         json.NumberNode("height", float64(height)),
		"timestamp":      json.NumberNode("timestamp", float64(now)),
		"avgBlockTimeMs": json.NumberNode("avgBlockTimeMs", float64(avgBlockTimeMs)),
		"halvings":       json.ArrayNode("", halvings),
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func isEmissionEnded(height int64) bool {
	return height > GetEndHeight()
}
