package gns

import (
	"std"
	"strconv"
	"time"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

// init 12 years halving tier block
/*
	NOTE: assume block will be created every 2 second by default
	2 second = 1 block
	1 minute = 30 block
	1 hour = 1800 block
	1 day = 43200 block
	(365 days) 1 year = 15768000 block

	2 year = +31536000 block
	4 year = +63072000 block
	6 year = +94608000 block
	8 year = +126144000 block
	12 year = +189216000 block
*/
const YEAR_BLOCK int64 = 15768000

const TIMESTAMP_365DAYS int64 = 31536000

var avgBlockTimeMs int64 = 2000 // 2000s = 2s for default

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
		halvingYearBlock[i] = height + YEAR_BLOCK*i
		halvingYearTimestamp[i] = startTimestamp + (TIMESTAMP_365DAYS * i)

		amountPerYear := halvingYearAmount[i]  // amount per year
		amountPerDay := amountPerYear / 365    // amount per day
		amountPerBlock := amountPerDay / 43200 // amount per block ( 1 day = 43200 block (2s/block) )

		amountPerBlockPerHalvingYear[i] = uint64(amountPerBlock)
	}
}

func SetAvgBlockTimeInMs(ms int64) {
	println()

	// admin or governance or staker only
	caller := std.PrevRealm().Addr()

	if caller != consts.GNOSWAP_ADMIN && caller != consts.GOV_ADDR && caller != consts.STAKER_ADDR {
		panic(
			ufmt.Sprintf(
				"only admin(%s) or governance(%s) or staker(%s) can set avg block time, called from %s",
				consts.GNOSWAP_ADMIN,
				consts.GOV_ADDR,
				consts.STAKER_ADDR,
				caller,
			),
		)
	}

	before := avgBlockTimeMs
	avgBlockTimeMs = ms

	// which year current time is in
	now := time.Now().Unix()
	height := std.GetHeight()
	println("GNS_HALVING__now_time:", now)
	println("GNS_HALVING__now_height:", height)
	year, endTimestamp := GetHalvingYearByTimestamp(now)
	println("GNS_HALVING__year:", year, ", endTimestamp:", endTimestamp)

	// how much time left to next halving
	timeLeft := endTimestamp - now
	println("GNS_HALVING__timeLeft:", timeLeft)

	// how many block left to next halving
	timeLeftMs := timeLeft * 1000
	println("GNS_HALVING__timeLeftMs:", timeLeftMs)
	blockLeft := timeLeftMs / avgBlockTimeMs
	println("GNS_HALVING__blockLeft:", blockLeft)

	// how many reward left to next halving
	minted := TotalMinted()
	println("GNS_HALVING__minted:", minted)
	amountLeft := halvingYearAccuAmount[year] - minted
	println("GNS_HALVING__amountLeft:", amountLeft)

	// how much reward per block
	adjustedAmountPerBlock := amountLeft / uint64(blockLeft)
	println("GNS_HALVING__adjustedAmountPerBlock:", adjustedAmountPerBlock)

	// update it
	println("GNS_HALVING__old_amountPerBlockPerHalvingYear[year]:", amountPerBlockPerHalvingYear[year])
	amountPerBlockPerHalvingYear[year] = adjustedAmountPerBlock
	println("GNS_HALVING__new_amountPerBlockPerHalvingYear[year]:", amountPerBlockPerHalvingYear[year])
	println()

	// adjust halving block
	for year, block := range halvingYearBlock {
		// XXX TODO: no need to adjust previous year

		println("GNS_HALVING__ > year:\t\t", year)

		yearEnd := halvingYearTimestamp[year]
		println("GNS_HALVING__ > yearEnd:\t", yearEnd)

		if now >= yearEnd {
			println("GNS_HALVING__ > already passed this year", year)
			println()
			continue
		}
		diff := yearEnd - now
		println("GNS_HALVING__ > diff:\t\t", diff)

		numBlock := diff * 1000 / avgBlockTimeMs
		println("GNS_HALVING__ > numBlock:\t", numBlock)

		halvingYearBlock[year] = height + numBlock
		println("GNS_HALVING__ > origBlock:\t", block)
		println("GNS_HALVING__ > newBlock:\t", halvingYearBlock[year])
		println()
	}

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"m_func", "SetAvgBlockTimeInMs",
		"before", int64ToStr(before),
		"after", int64ToStr(avgBlockTimeMs),
	)

}

func GetAmountByHeight(height int64) uint64 {
	halvingYear := GetHalvingYearByHeight(height)

	return amountPerBlockPerHalvingYear[halvingYear]
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

	// MARSHAL
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
	yearMs := TIMESTAMP_365DAYS * 1000 // how much millisecond in a year
	return yearMs / ms                 // how many block in a year
}

func origCaller() string {
	return std.GetOrigCaller().String()
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

func int64ToStr(i int64) string {
	return strconv.FormatInt(i, 10)
}
