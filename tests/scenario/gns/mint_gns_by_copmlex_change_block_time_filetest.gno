// Verify GNS emission lifecycle and block time change edge cases
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	_ "gno.land/r/gnoswap/v1/staker"
)

var t *testing.T

var (
	user01Addr   = testutils.TestAddress("user01Addr")
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
)

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2000ms
)

func main() {
	println("[SCENARIO] 1. Initialize emission (full lifecycle test)")
	initEmission()
	println()

	// --- FULL LIFECYCLE TEST ---
	println("[SCENARIO] 2. Year 1: Mint after skipping 1 year (block time 2000ms)")
	remainingBlockCount := gns.GetHalvingYearEndBlock(1) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 3. Year 2: Mint after skipping 1 year (block time 2000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(2) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 4. Year 3: Change block time to 1000ms at 20% of year, then mint at year end")
	blockCount := milliSecondsOfYear / gns.AvgBlockTimeInMs() * 2 / 10
	testing.SkipHeights(blockCount)
	println("[INFO] current block height", std.ChainHeight())
	changeBlockTime(1000)
	println()

	println("[SCENARIO] 5. Year 3: Get halving years")
	getHalvingYears()
	println()

	// NOTE: cannot set block time after emission period has ended
}

func initEmission() {
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/staker"))
}

func mintGNS() {
	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/emission"))
	mintedAmount := gns.MintGns(cross, user01Addr)
	totalMintedAmount := gns.MintedEmissionAmount()
	ufmt.Printf("[EXPECTED] minted amount: %d\n", mintedAmount)
	ufmt.Printf("[EXPECTED] total minted amount: %d\n", totalMintedAmount)
}

func changeBlockTime(blockTime int64) {
	testing.SetOriginCaller(adminAddr)
	currentYear := gns.HalvingYearByHeight(std.ChainHeight())
	prevEndBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	prevAmountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)
	gns.SetAvgBlockTimeInMs(cross, blockTime)
	endBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	amountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)
	ufmt.Printf("[INFO] block time changed to %dms\n", blockTime)
	ufmt.Printf("[INFO] current year is %d\n", currentYear)
	ufmt.Printf("[EXPECTED] end block height: %d -> %d\n", prevEndBlockHeight, endBlockHeight)
	ufmt.Printf("[EXPECTED] amount per block: %d -> %d\n", prevAmountPerBlock, amountPerBlock)
}

func verifyTotalEmission(expectedTotal int64) {
	totalMintedAmount := gns.MintedEmissionAmount()
	ufmt.Printf("[EXPECTED] total emission after 12 years: %d (expected: %d)\n", totalMintedAmount, expectedTotal)
}

func verifyYearEmission(year int64, expectedAmount int64) {
	totalMintedAmount := gns.MintedEmissionAmount()
	ufmt.Printf("[EXPECTED] Year %d total emission: %d (expected: %d)\n", year, totalMintedAmount, expectedAmount)
}

func getHalvingYears() {
	println("[INFO] current halving year", gns.HalvingYearByHeight(std.ChainHeight()))
	println("[INFO] average block time in ms", gns.AvgBlockTimeInMs())
	for year := int64(1); year <= 12; year++ {
		startBlockHeight := gns.GetHalvingYearStartBlock(year)
		endBlockHeight := gns.GetHalvingYearEndBlock(year)
		blockCount := endBlockHeight - startBlockHeight + 1
		ufmt.Printf("[INFO] halving year %d block range %d~%d (block count: %d)\n", year, startBlockHeight, endBlockHeight, blockCount)
	}
}

// Output:
// [SCENARIO] 1. Initialize emission (full lifecycle test)
//
// [SCENARIO] 2. Year 1: Mint after skipping 1 year (block time 2000ms)
// [INFO] current block height 15768123
// [EXPECTED] minted amount: 225000000000000
// [EXPECTED] total minted amount: 225000000000000
//
// [SCENARIO] 3. Year 2: Mint after skipping 1 year (block time 2000ms)
// [INFO] current block height 31536123
// [EXPECTED] minted amount: 225000000000000
// [EXPECTED] total minted amount: 450000000000000
//
// [SCENARIO] 4. Year 3: Change block time to 1000ms at 20% of year, then mint at year end
// [INFO] current block height 34689723
// [INFO] block time changed to 1000ms
// [INFO] current year is 3
// [EXPECTED] end block height: 47304123 -> 59918523
// [EXPECTED] amount per block: 7134703 -> 4459189
//
// [SCENARIO] 5. Year 3: Get halving years
// [INFO] current halving year 3
// [INFO] average block time in ms 1000
// [INFO] halving year 1 block range 124~15768123 (block count: 15768000)
// [INFO] halving year 2 block range 15768124~31536123 (block count: 15768000)
// [INFO] halving year 3 block range 31536124~59918523 (block count: 28382400)
// [INFO] halving year 4 block range 59918524~91454523 (block count: 31536000)
// [INFO] halving year 5 block range 91454524~122990523 (block count: 31536000)
// [INFO] halving year 6 block range 122990524~154526523 (block count: 31536000)
// [INFO] halving year 7 block range 154526524~186062523 (block count: 31536000)
// [INFO] halving year 8 block range 186062524~217598523 (block count: 31536000)
// [INFO] halving year 9 block range 217598524~249134523 (block count: 31536000)
// [INFO] halving year 10 block range 249134524~280670523 (block count: 31536000)
// [INFO] halving year 11 block range 280670524~312206523 (block count: 31536000)
// [INFO] halving year 12 block range 312206524~343742523 (block count: 31536000)
