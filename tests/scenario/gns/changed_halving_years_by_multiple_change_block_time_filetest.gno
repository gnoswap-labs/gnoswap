// changed halving years by multiple change block time (2000ms -> 1000ms -> 5000ms)
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/gns"

	_ "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/gnoswap/v1/access"
)

var t *testing.T

var adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2000ms
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Get halving years (block time is 2000ms)")
	getHalvingYears()
	println()

	ufmt.Println("[SCENARIO] 3. Skip 3942000 blocks and change block time to 1000ms (skip to 25% of 1 year)")
	testing.SkipHeights(3942000)
	changeBlockTime(1000)
	println()

	ufmt.Println("[SCENARIO] 4. Get halving years (block time is 1000ms)")
	getHalvingYears()

	ufmt.Println("[SCENARIO] 5. Skip 3942000 blocks and change block time to 5000ms (skip to 50% of 1 year)")
	testing.SkipHeights(3942000)
	changeBlockTime(5000)
	println()

	ufmt.Println("[SCENARIO] 6. Get halving years (block time is 5000ms)")
	getHalvingYears()
	println()
}

func initEmission() {}

func getHalvingYears() {
	println("[INFO] current halving years", gns.GetHalvingYearByHeight(std.ChainHeight()))
	println("[INFO] average block time in ms", gns.GetAvgBlockTimeInMs())

	for year := int64(1); year <= 12; year++ {
		startBlockHeight := gns.GetHalvingYearStartBlock(year)
		endBlockHeight := gns.GetHalvingYearEndBlock(year)
		blockCount := endBlockHeight - startBlockHeight + 1
		ufmt.Printf("[EXPECTED] halving year %d block range %d~%d (block count: %d)\n", year, startBlockHeight, endBlockHeight, blockCount)
	}
}

func changeBlockTime(blockTime int64) {
	testing.SetOriginCaller(adminAddr)

	currentYear := gns.GetHalvingYearByHeight(std.ChainHeight())

	// get previous end block height and amount per block
	prevEndBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	prevAmountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)

	// change block time
	gns.SetAvgBlockTimeInMsByAdmin(cross, blockTime)

	// get current end block height and amount per block
	endBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	amountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)

	ufmt.Printf("[INFO] current year is %d\n", currentYear)
	ufmt.Printf("[EXPECTED] end block height should be changed %d to %d\n", prevEndBlockHeight, endBlockHeight)
	ufmt.Printf("[EXPECTED] amount per block should be changed %d to %d\n", prevAmountPerBlock, amountPerBlock)
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Get halving years (block time is 2000ms)
// [INFO] current halving years 1
// [INFO] average block time in ms 2000
// [EXPECTED] halving year 1 block range 124~15768123 (block count: 15768000)
// [EXPECTED] halving year 2 block range 15768124~31536123 (block count: 15768000)
// [EXPECTED] halving year 3 block range 31536124~47304123 (block count: 15768000)
// [EXPECTED] halving year 4 block range 47304124~63072123 (block count: 15768000)
// [EXPECTED] halving year 5 block range 63072124~78840123 (block count: 15768000)
// [EXPECTED] halving year 6 block range 78840124~94608123 (block count: 15768000)
// [EXPECTED] halving year 7 block range 94608124~110376123 (block count: 15768000)
// [EXPECTED] halving year 8 block range 110376124~126144123 (block count: 15768000)
// [EXPECTED] halving year 9 block range 126144124~141912123 (block count: 15768000)
// [EXPECTED] halving year 10 block range 141912124~157680123 (block count: 15768000)
// [EXPECTED] halving year 11 block range 157680124~173448123 (block count: 15768000)
// [EXPECTED] halving year 12 block range 173448124~189216123 (block count: 15768000)
//
// [SCENARIO] 3. Skip 3942000 blocks and change block time to 1000ms (skip to 25% of 1 year)
// [INFO] current year is 1
// [EXPECTED] end block height should be changed 15768123 to 27594123
// [EXPECTED] amount per block should be changed 14269406 to 9512937
//
// [SCENARIO] 4. Get halving years (block time is 1000ms)
// [INFO] current halving years 1
// [INFO] average block time in ms 1000
// [EXPECTED] halving year 1 block range 124~27594123 (block count: 27594000)
// [EXPECTED] halving year 2 block range 27594124~59130123 (block count: 31536000)
// [EXPECTED] halving year 3 block range 59130124~90666123 (block count: 31536000)
// [EXPECTED] halving year 4 block range 90666124~122202123 (block count: 31536000)
// [EXPECTED] halving year 5 block range 122202124~153738123 (block count: 31536000)
// [EXPECTED] halving year 6 block range 153738124~185274123 (block count: 31536000)
// [EXPECTED] halving year 7 block range 185274124~216810123 (block count: 31536000)
// [EXPECTED] halving year 8 block range 216810124~248346123 (block count: 31536000)
// [EXPECTED] halving year 9 block range 248346124~279882123 (block count: 31536000)
// [EXPECTED] halving year 10 block range 279882124~311418123 (block count: 31536000)
// [EXPECTED] halving year 11 block range 311418124~342954123 (block count: 31536000)
// [EXPECTED] halving year 12 block range 342954124~374490123 (block count: 31536000)
// [SCENARIO] 5. Skip 3942000 blocks and change block time to 5000ms (skip to 50% of 1 year)
// [INFO] current year is 1
// [EXPECTED] end block height should be changed 27594123 to 11826123
// [EXPECTED] amount per block should be changed 9512937 to 57077625
//
// [SCENARIO] 6. Get halving years (block time is 5000ms)
// [INFO] current halving years 1
// [INFO] average block time in ms 5000
// [EXPECTED] halving year 1 block range 124~11826123 (block count: 11826000)
// [EXPECTED] halving year 2 block range 11826124~18133323 (block count: 6307200)
// [EXPECTED] halving year 3 block range 18133324~24440523 (block count: 6307200)
// [EXPECTED] halving year 4 block range 24440524~30747723 (block count: 6307200)
// [EXPECTED] halving year 5 block range 30747724~37054923 (block count: 6307200)
// [EXPECTED] halving year 6 block range 37054924~43362123 (block count: 6307200)
// [EXPECTED] halving year 7 block range 43362124~49669323 (block count: 6307200)
// [EXPECTED] halving year 8 block range 49669324~55976523 (block count: 6307200)
// [EXPECTED] halving year 9 block range 55976524~62283723 (block count: 6307200)
// [EXPECTED] halving year 10 block range 62283724~68590923 (block count: 6307200)
// [EXPECTED] halving year 11 block range 68590924~74898123 (block count: 6307200)
// [EXPECTED] halving year 12 block range 74898124~81205323 (block count: 6307200)
