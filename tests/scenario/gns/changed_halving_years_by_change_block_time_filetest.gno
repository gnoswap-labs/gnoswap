// changed halving years by change block time (2000ms -> 3500ms)
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/gnoswap/v1/access"
	_ "gno.land/r/gnoswap/v1/staker"
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

	ufmt.Println("[SCENARIO] 3. Skip 788400 blocks (distribute of half of 1 year)")
	testing.SkipHeights(788400)
	println()

	ufmt.Println("[SCENARIO] 4. Change block time to 3500ms (2000ms -> 3500ms)")
	changeBlockTime(3500)
	println()

	ufmt.Println("[SCENARIO] 5. Get halving years (block time is 3500ms)")
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
// [SCENARIO] 3. Skip 788400 blocks (distribute of half of 1 year)
//
// [SCENARIO] 4. Change block time to 3500ms (2000ms -> 3500ms)
// [INFO] current year is 1
// [EXPECTED] end block height should be changed 15768123 to 9348294
// [EXPECTED] amount per block should be changed 14269406 to 26285749
//
// [SCENARIO] 5. Get halving years (block time is 3500ms)
// [INFO] current halving years 1
// [INFO] average block time in ms 3500
// [EXPECTED] halving year 1 block range 124~9348294 (block count: 9348171)
// [EXPECTED] halving year 2 block range 9348295~18358580 (block count: 9010286)
// [EXPECTED] halving year 3 block range 18358581~27368865 (block count: 9010285)
// [EXPECTED] halving year 4 block range 27368866~36379151 (block count: 9010286)
// [EXPECTED] halving year 5 block range 36379152~45389437 (block count: 9010286)
// [EXPECTED] halving year 6 block range 45389438~54399723 (block count: 9010286)
// [EXPECTED] halving year 7 block range 54399724~63410008 (block count: 9010285)
// [EXPECTED] halving year 8 block range 63410009~72420294 (block count: 9010286)
// [EXPECTED] halving year 9 block range 72420295~81430580 (block count: 9010286)
// [EXPECTED] halving year 10 block range 81430581~90440865 (block count: 9010285)
// [EXPECTED] halving year 11 block range 90440866~99451151 (block count: 9010286)
// [EXPECTED] halving year 12 block range 99451152~108461437 (block count: 9010286)
