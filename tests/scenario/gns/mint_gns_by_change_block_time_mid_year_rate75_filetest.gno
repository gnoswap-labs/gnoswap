// mint gns by change block time at mid year (at 75% of 2nd year)
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
)

var t *testing.T

var (
	user01Addr   = testutils.TestAddress("user01Addr")
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
)

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2000ms
)

func main() {
	println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	println("[SCENARIO] 2. Mint GNS when skipped 15768000 blocks (distribute of 1 year)")
	testing.SkipHeights(15768000)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 3. Mint GNS when skipped 11826000 blocks (75% of 1 year)")
	testing.SkipHeights(11826000)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 4. Get halving years (block time is 2000ms)")
	getHalvingYears()
	println()

	println("[SCENARIO] 5. Change block time to 4000ms (2000ms -> 4000ms)")
	changeBlockTime(4000)
	println()

	println("[SCENARIO] 6. Get halving years (block time is 4000ms)")
	getHalvingYears()
	println()
}

func initEmission() {}

func mintGNS() {
	testing.SetRealm(std.NewCodeRealm(consts.EMISSION_PATH))

	mintedAmount := gns.MintGns(cross, user01Addr)

	totalMintedAmount := gns.GetMintedEmissionAmount()

	ufmt.Printf("[EXPECTED] minted amount should be %d\n", mintedAmount)
	ufmt.Printf("[EXPECTED] total minted amount should be %d\n", totalMintedAmount)
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

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint GNS when skipped 15768000 blocks (distribute of 1 year)
// [INFO] current block height 15768123
// [EXPECTED] minted amount should be 225000000000000
// [EXPECTED] total minted amount should be 225000000000000
//
// [SCENARIO] 3. Mint GNS when skipped 11826000 blocks (75% of 1 year)
// [INFO] current block height 27594123
// [EXPECTED] minted amount should be 168749995356000
// [EXPECTED] total minted amount should be 393749995356000
//
// [SCENARIO] 4. Get halving years (block time is 2000ms)
// [INFO] current halving years 2
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
// [SCENARIO] 5. Change block time to 4000ms (2000ms -> 4000ms)
// [INFO] current year is 2
// [EXPECTED] end block height should be changed 31536123 to 29565123
// [EXPECTED] amount per block should be changed 14269406 to 28538815
//
// [SCENARIO] 6. Get halving years (block time is 4000ms)
// [INFO] current halving years 2
// [INFO] average block time in ms 4000
// [EXPECTED] halving year 1 block range 124~15768123 (block count: 15768000)
// [EXPECTED] halving year 2 block range 15768124~29565123 (block count: 13797000)
// [EXPECTED] halving year 3 block range 29565124~37449123 (block count: 7884000)
// [EXPECTED] halving year 4 block range 37449124~45333123 (block count: 7884000)
// [EXPECTED] halving year 5 block range 45333124~53217123 (block count: 7884000)
// [EXPECTED] halving year 6 block range 53217124~61101123 (block count: 7884000)
// [EXPECTED] halving year 7 block range 61101124~68985123 (block count: 7884000)
// [EXPECTED] halving year 8 block range 68985124~76869123 (block count: 7884000)
// [EXPECTED] halving year 9 block range 76869124~84753123 (block count: 7884000)
// [EXPECTED] halving year 10 block range 84753124~92637123 (block count: 7884000)
// [EXPECTED] halving year 11 block range 92637124~100521123 (block count: 7884000)
// [EXPECTED] halving year 12 block range 100521124~108405123 (block count: 7884000)
