package gns

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/seqid"
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

const HALVING_AMOUNTS = []uint64{
	// MAX_EMISSION_AMOUNT = 225000000000000
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

var (
	BLOCK_PER_YEAR = consts.TIMESTAMP_YEAR / consts.BLOCK_GENERATION_INTERVAL
	BLOCK_PER_DAY  = consts.TIMESTAMP_DAY / consts.BLOCK_GENERATION_INTERVAL

	avgBlockTimeMs int64 = consts.SECOND_IN_MILLISECOND * consts.BLOCK_GENERATION_INTERVAL
)

var (
	startHeight    int64
	startTimestamp int64
)

var (
	halvingYearBlock             = avl.NewTree() // year -> last block height
	halvingYearTimestamp         = avl.NewTree() // year -> timestamp
	halvingYearMaxAmount         = avl.NewTree() // year -> (maximum) mintAmount
	halvingYearMintAmount        = avl.NewTree() // year -> (actual) mintAmount
	halvingYearAccuAmount        = avl.NewTree() // year -> accuAmount
	amountPerBlockPerHalvingYear = avl.NewTree() // year -> amount per block
)

func init() {
	startHeight = std.GetHeight()
	startTimestamp = time.Now().Unix()

	for year := int64(1); year < 13; year++ {
		setHalvingYearMaxAmount(year, HALVING_AMOUNTS[year-1])

		if year == 1 {
			setHalvingYearAccuAmount(year, HALVING_AMOUNTS[year-1])
		} else {
			setHalvingYearAccuAmount(year, GetHalvingYearAccuAmount(year-1)+HALVING_AMOUNTS[year-1])
		}

		setHalvingYearBlock(year, startHeight+BLOCK_PER_YEAR*year)
		setHalvingYearTimestamp(year, startTimestamp+(consts.TIMESTAMP_YEAR*year))
		setHalvingYearMintAmount(year, uint64(0))

		amountPerYear := GetHalvingYearMaxAmount(year)         // amount per year
		amountPerDay := amountPerYear / consts.DAY_PER_YEAR    // amount per day
		amountPerBlock := amountPerDay / uint64(BLOCK_PER_DAY) // amount per block
		setAmountPerBlockPerHalvingYear(year, uint64(amountPerBlock))
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
	year, endTimestamp := getHalvingYearAndEndTimestamp(now)

	// how much time left to next halving
	timeLeft := endTimestamp - now

	// how many block left to next halving
	timeLeftMs := timeLeft * consts.SECOND_IN_MILLISECOND
	blockLeft := timeLeftMs / avgBlockTimeMs
	// how many reward left to next halving
	minted := MintedEmissionAmount()
	amountLeft := GetHalvingYearAccuAmount(year) - minted

	// how much reward per block
	adjustedAmountPerBlock := amountLeft / uint64(blockLeft)

	// update it
	setAmountPerBlockPerHalvingYear(year, adjustedAmountPerBlock)

	for year := int64(1); year < 13; year++ {
		yearEndTimestamp := GetHalvingYearTimestamp(year)

		if now >= yearEndTimestamp {
			continue
		}

		diff := yearEndTimestamp - now
		numBlock := diff * consts.SECOND_IN_MILLISECOND / avgBlockTimeMs
		setHalvingYearBlock(year, height+numBlock)
	}
}

func GetAmountByHeight(height int64) uint64 {
	halvingYear := GetHalvingYearByHeight(height)
	return GetAmountPerBlockPerHalvingYear(halvingYear)
}

// GetHalvingYearByHeight returns the halving year by height
func GetHalvingYearByHeight(height int64) int64 {
	for year := int64(1); year < 13; year++ {
		block := GetHalvingYearBlock(year)
		if height <= block {
			return year
		}
	}

	return 0
}

func getHalvingYearAndEndTimestamp(timestamp int64) (int64, int64) {
	timestamp -= startTimestamp

	divValue := timestamp / consts.TIMESTAMP_YEAR
	modValue := timestamp % consts.TIMESTAMP_YEAR

	if modValue == 0 {
		if divValue > 12 {
			return 0, 0
		}

		return divValue, startTimestamp + (consts.TIMESTAMP_YEAR * divValue)
	}

	if divValue+1 > 12 {
		return 0, 0
	}

	return divValue + 1, startTimestamp + (consts.TIMESTAMP_YEAR * (divValue + 1))
}

func GetHalvingInfo() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	halvings := make([]*json.Node, 0)
	// for year, block := range halvingYearBlock {
	halvingYearBlock.Iterate("", "", func(yearStr string, value interface{}) bool {
		yearInt, _ := strconv.ParseInt(yearStr, 10, 64)
		block := value.(int64)
		halvings = append(halvings, json.ObjectNode("", map[string]*json.Node{
			"year":   json.StringNode("year", yearStr),
			"block":  json.NumberNode("block", float64(block)),
			"amount": json.NumberNode("amount", float64(GetAmountPerBlockPerHalvingYear(yearInt))),
		}))

		return true
	})

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

func GetHalvingYearBlock(year int64) int64 {
	iBlock, exist := halvingYearBlock.Get(strconv.FormatInt(year, 10))
	if !exist {
		panic(ufmt.Sprintf("halving.gno__GetHalvingYearBlock() || year(%d) not found", year))
	}

	return iBlock.(int64)
}

func setHalvingYearBlock(year int64, block int64) {
	halvingYearBlock.Set(strconv.FormatInt(year, 10), block)

}

func GetHalvingYearTimestamp(year int64) int64 {
	iTimestamp, exist := halvingYearTimestamp.Get(strconv.FormatInt(year, 10))
	if !exist {
		panic(ufmt.Sprintf("halving.gno__GetHalvingYearTimestamp() || year(%d) not found", year))
	}

	return iTimestamp.(int64)
}

func setHalvingYearTimestamp(year int64, timestamp int64) {
	halvingYearTimestamp.Set(strconv.FormatInt(year, 10), timestamp)
}

func GetHalvingYearMaxAmount(year int64) uint64 {
	iAmount, exist := halvingYearMaxAmount.Get(strconv.FormatInt(year, 10))
	if !exist {
		panic(ufmt.Sprintf("halving.gno__GetHalvingYearMaxAmount() || year(%d) not found", year))
	}

	return iAmount.(uint64)
}

func setHalvingYearMaxAmount(year int64, amount uint64) {
	halvingYearMaxAmount.Set(strconv.FormatInt(year, 10), amount)
}

func GetHalvingYearMintAmount(year int64) uint64 {
	iAmount, exist := halvingYearMintAmount.Get(strconv.FormatInt(year, 10))
	if !exist {
		panic(ufmt.Sprintf("halving.gno__GetHalvingYearMintAmount() || year(%d) not found", year))
	}

	return iAmount.(uint64)
}

func setHalvingYearMintAmount(year int64, amount uint64) {
	halvingYearMintAmount.Set(strconv.FormatInt(year, 10), amount)
}

func GetHalvingYearAccuAmount(year int64) uint64 {
	iAmount, exist := halvingYearAccuAmount.Get(strconv.FormatInt(year, 10))
	if !exist {
		panic(ufmt.Sprintf("halving.gno__GetHalvingYearAccuAmount() || year(%d) not found", year))
	}

	return iAmount.(uint64)
}

func setHalvingYearAccuAmount(year int64, amount uint64) {
	halvingYearAccuAmount.Set(strconv.FormatInt(year, 10), amount)
}

func GetAmountPerBlockPerHalvingYear(year int64) uint64 {
	iAmount, exist := amountPerBlockPerHalvingYear.Get(strconv.FormatInt(year, 10))
	if !exist {
		panic(ufmt.Sprintf("halving.gno__GetAmountPerBlockPerHalvingYear() || year(%d) not found", year))
	}

	return iAmount.(uint64)
}

func setAmountPerBlockPerHalvingYear(year int64, amount uint64) {
	amountPerBlockPerHalvingYear.Set(strconv.FormatInt(year, 10), amount)
}

func getSeqID(num int64) string {
	return seqid.ID(uint64(num)).Binary()
}
