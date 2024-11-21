package gns

import (
	"std"
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

var (
	BLOCK_PER_YEAR = consts.TIMESTAMP_YEAR / consts.BLOCK_GENERATION_INTERVAL
	BLOCK_PER_DAY  = consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL

	avgBlockTimeMs int64 = consts.SECOND_IN_MILLISECOND * consts.BLOCK_GENERATION_INTERVAL
)

var (
	initialized    bool
	startHeight    int64
	startTimestamp int64
)

var halvingYearBlock = make(map[int64]int64)     // year => block
var halvingYearTimestamp = make(map[int64]int64) // year => timestamp

var halvingYearAmount = make(map[int64]uint64)     // year => mintAmount
var halvingYearMintAmount = make(map[int64]uint64) // year => (actual) mintAmount
var halvingYearAccuAmount = make(map[int64]uint64) // year => accuAmount
func init() {
	// yearly mint amount
	halvingYearAmount[1] = 18_750_000_000_000 * 12 // 225000000000000
	halvingYearAmount[2] = 18_750_000_000_000 * 12 // 225000000000000
	halvingYearAmount[3] = 9_375_000_000_000 * 12  // 112500000000000
	halvingYearAmount[4] = 9_375_000_000_000 * 12  // 112500000000000
	halvingYearAmount[5] = 4_687_500_000_000 * 12  // 56250000000000
	halvingYearAmount[6] = 4_687_500_000_000 * 12  // 56250000000000
	halvingYearAmount[7] = 2_343_750_000_000 * 12  // 28125000000000
	halvingYearAmount[8] = 2_343_750_000_000 * 12  // 28125000000000
	halvingYearAmount[9] = 1_171_875_000_000 * 12  // 14062500000000
	halvingYearAmount[10] = 1_171_875_000_000 * 12 // 14062500000000
	halvingYearAmount[11] = 1_171_875_000_000 * 12 // 14062500000000
	halvingYearAmount[12] = 1_171_875_000_000 * 12 // 14062500000000

	// yearly accumulated mint amount
	halvingYearAccuAmount[1] = halvingYearAmount[1]
	halvingYearAccuAmount[2] = halvingYearAccuAmount[1] + halvingYearAmount[2]
	halvingYearAccuAmount[3] = halvingYearAccuAmount[2] + halvingYearAmount[3]
	halvingYearAccuAmount[4] = halvingYearAccuAmount[3] + halvingYearAmount[4]
	halvingYearAccuAmount[5] = halvingYearAccuAmount[4] + halvingYearAmount[5]
	halvingYearAccuAmount[6] = halvingYearAccuAmount[5] + halvingYearAmount[6]
	halvingYearAccuAmount[7] = halvingYearAccuAmount[6] + halvingYearAmount[7]
	halvingYearAccuAmount[8] = halvingYearAccuAmount[7] + halvingYearAmount[8]
	halvingYearAccuAmount[9] = halvingYearAccuAmount[8] + halvingYearAmount[9]
	halvingYearAccuAmount[10] = halvingYearAccuAmount[9] + halvingYearAmount[10]
	halvingYearAccuAmount[11] = halvingYearAccuAmount[10] + halvingYearAmount[11]
	halvingYearAccuAmount[12] = halvingYearAccuAmount[11] + halvingYearAmount[12]
}

var amountPerBlockPerHalvingYear = make(map[int64]uint64) // year => reward per block

func init() {
	height := std.GetHeight()

	startHeight = height
	startTimestamp = time.Now().Unix()

	initialized = true

	for i := int64(1); i < 13; i++ {
		halvingYearBlock[i] = height + BLOCK_PER_YEAR*i
		halvingYearTimestamp[i] = startTimestamp + (consts.TIMESTAMP_YEAR * i)

		amountPerYear := halvingYearAmount[i]                  // amount per year
		amountPerDay := amountPerYear / consts.DAY_PER_YEAR    // amount per day
		amountPerBlock := amountPerDay / uint64(BLOCK_PER_DAY) // amount per block

		amountPerBlockPerHalvingYear[i] = uint64(amountPerBlock)
	}
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

	// set it
	avgBlockTimeMs = ms

	// which year current time is in
	now := time.Now().Unix()
	height := std.GetHeight()
	year, endTimestamp := GetHalvingYearByTimestamp(now)

	// how much time left to next halving
	timeLeft := endTimestamp - now

	// how many block left to next halving
	timeLeftMs := timeLeft * consts.SECOND_IN_MILLISECOND
	blockLeft := timeLeftMs / avgBlockTimeMs

	// how many reward left to next halving
	minted := TotalMinted()
	amountLeft := halvingYearAccuAmount[year] - minted

	// how much reward per block
	adjustedAmountPerBlock := amountLeft / uint64(blockLeft)

	// update it
	amountPerBlockPerHalvingYear[year] = adjustedAmountPerBlock

	// adjust halving block
	for keyYear, _ := range halvingYearBlock {
		yearEnd := halvingYearTimestamp[keyYear]

		if now >= yearEnd {
			continue
		}

		diff := yearEnd - now
		numBlock := diff * consts.SECOND_IN_MILLISECOND / avgBlockTimeMs
		halvingYearBlock[keyYear] = height + numBlock
	}
}

func GetAmountByHeight(height int64) uint64 {
	halvingYear := GetHalvingYearByHeight(height)

	return amountPerBlockPerHalvingYear[halvingYear]
}

func GetAmountByYear(year int64) uint64 {
	return amountPerBlockPerHalvingYear[year]
}

func GetHalvingYearByHeight(height int64) int64 {
	// determine which halving year block is in
	for year, block := range halvingYearBlock {
		if height <= block {
			return year
		}
	}

	return 0
}

func GetHalvingYearByTimestamp(timestamp int64) (int64, int64) {
	// determine which halving tier block is in
	for tier, ts := range halvingYearTimestamp {
		if timestamp <= ts {
			return tier, ts
		}
	}

	return 0, 0
}

func GetHalvingYearBlock(year int64) int64 {
	return halvingYearBlock[year]
}

func GetHalvingInfo() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	halvings := make([]*json.Node, 0)
	for year, block := range halvingYearBlock {
		halvings = append(halvings, json.ObjectNode("", map[string]*json.Node{
			"year":   json.NumberNode("year", float64(year)),
			"block":  json.NumberNode("block", float64(block)),
			"amount": json.NumberNode("amount", float64(amountPerBlockPerHalvingYear[year])),
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

func getYearlyBlockForTimestampMs(ms int64) int64 {
	yearMs := consts.TIMESTAMP_YEAR * consts.SECOND_IN_MILLISECOND // how much millisecond in a year
	return int64(yearMs) / ms                                      // how many block in a year
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func callType() string {
	if prevRealm() == "" {
		return "DIRECT"
	}

	return "INDIRECT"
}
