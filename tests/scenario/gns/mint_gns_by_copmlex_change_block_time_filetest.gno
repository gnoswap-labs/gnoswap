// Verify GNS emission lifecycle and block time change edge cases
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"
	_ "gno.land/r/gnoswap/v1/staker"
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
	blockCount := milliSecondsOfYear / gns.GetAvgBlockTimeInMs() * 2 / 10
	testing.SkipHeights(blockCount)
	println("[INFO] current block height", std.ChainHeight())
	changeBlockTime(1000)
	println()

	println("[SCENARIO] 5. Year 3: Get halving years")
	getHalvingYears()
	println()

	println("[SCENARIO] 6. Year 3: Mint after skipping remaining year (block time 1000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(3) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 7. Year 4: Mint after skipping 1 year (block time 1000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(4) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 8. Year 5: Change block time to 3000ms at 70% of year, then mint at year end")
	blockCount = milliSecondsOfYear / gns.GetAvgBlockTimeInMs() * 7 / 10
	testing.SkipHeights(blockCount)
	println("[INFO] current block height", std.ChainHeight())
	changeBlockTime(3000)
	println()

	println("[SCENARIO] 9. Year 5: Get halving years")
	getHalvingYears()
	println()

	println("[SCENARIO] 10. Year 5: Mint after skipping remaining year (block time 3000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(5) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 11. Year 6: Change block time to 2000ms at 40% of year, then mint at year end")
	blockCount = milliSecondsOfYear / gns.GetAvgBlockTimeInMs() * 4 / 10
	testing.SkipHeights(blockCount)
	println("[INFO] current block height", std.ChainHeight())
	changeBlockTime(2000)
	println()

	println("[SCENARIO] 12. Year 6: Get halving years")
	getHalvingYears()
	println()

	println("[SCENARIO] 13. Year 6: Mint after skipping remaining year (block time 2000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(6) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 14. Year 7: Mint after skipping 1 year (block time 2000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(7) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 15. Year 8: Mint after skipping 1 year (block time 2000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(8) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 16. Year 9: Mint after skipping 1 year (block time 2000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(9) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 17. Year 10: Change block time to 1000ms at 50% of year, then mint at year end")
	blockCount = milliSecondsOfYear / gns.GetAvgBlockTimeInMs() * 5 / 10
	testing.SkipHeights(blockCount)
	println("[INFO] current block height", std.ChainHeight())
	changeBlockTime(1000)
	println()

	println("[SCENARIO] 18. Year 10: Get halving years")
	getHalvingYears()
	println()

	println("[SCENARIO] 19. Year 10: Mint after skipping remaining year (block time 1000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(10) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 20. Year 11: Mint after skipping 1 year (block time 1000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(11) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 21. Year 12: Mint after skipping 1 year (block time 1000ms)")
	remainingBlockCount = gns.GetHalvingYearEndBlock(12) - std.ChainHeight()
	testing.SkipHeights(remainingBlockCount)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()
}

func initEmission() {
	testing.SetRealm(std.NewCodeRealm(consts.STAKER_PATH))
	emission.RegisterGnsChangeCallback(cross)
}

func mintGNS() {
	testing.SetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	mintedAmount := gns.MintGns(cross, user01Addr)
	totalMintedAmount := gns.GetMintedEmissionAmount()
	ufmt.Printf("[EXPECTED] minted amount: %d\n", mintedAmount)
	ufmt.Printf("[EXPECTED] total minted amount: %d\n", totalMintedAmount)
}

func changeBlockTime(blockTime int64) {
	testing.SetOriginCaller(adminAddr)
	currentYear := gns.GetHalvingYearByHeight(std.ChainHeight())
	prevEndBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	prevAmountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)
	gns.SetAvgBlockTimeInMsByAdmin(cross, blockTime)
	endBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	amountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)
	ufmt.Printf("[INFO] block time changed to %dms\n", blockTime)
	ufmt.Printf("[INFO] current year is %d\n", currentYear)
	ufmt.Printf("[EXPECTED] end block height: %d -> %d\n", prevEndBlockHeight, endBlockHeight)
	ufmt.Printf("[EXPECTED] amount per block: %d -> %d\n", prevAmountPerBlock, amountPerBlock)
}

func verifyTotalEmission(expectedTotal int64) {
	totalMintedAmount := gns.GetMintedEmissionAmount()
	ufmt.Printf("[EXPECTED] total emission after 12 years: %d (expected: %d)\n", totalMintedAmount, expectedTotal)
}

func verifyYearEmission(year int64, expectedAmount int64) {
	totalMintedAmount := gns.GetMintedEmissionAmount()
	ufmt.Printf("[EXPECTED] Year %d total emission: %d (expected: %d)\n", year, totalMintedAmount, expectedAmount)
}

func getHalvingYears() {
	println("[INFO] current halving year", gns.GetHalvingYearByHeight(std.ChainHeight()))
	println("[INFO] average block time in ms", gns.GetAvgBlockTimeInMs())
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
//
// [SCENARIO] 6. Year 3: Mint after skipping remaining year (block time 1000ms)
// [INFO] current block height 59918523
// [EXPECTED] minted amount: 112500000000000
// [EXPECTED] total minted amount: 562500000000000
//
// [SCENARIO] 7. Year 4: Mint after skipping 1 year (block time 1000ms)
// [INFO] current block height 91454523
// [EXPECTED] minted amount: 112500000000000
// [EXPECTED] total minted amount: 675000000000000
//
// [SCENARIO] 8. Year 5: Change block time to 3000ms at 70% of year, then mint at year end
// [INFO] current block height 113529723
// [INFO] block time changed to 3000ms
// [INFO] current year is 5
// [EXPECTED] end block height: 122990523 -> 116683323
// [EXPECTED] amount per block: 1783675 -> 17836757
//
// [SCENARIO] 9. Year 5: Get halving years
// [INFO] current halving year 5
// [INFO] average block time in ms 3000
// [INFO] halving year 1 block range 124~15768123 (block count: 15768000)
// [INFO] halving year 2 block range 15768124~31536123 (block count: 15768000)
// [INFO] halving year 3 block range 31536124~59918523 (block count: 28382400)
// [INFO] halving year 4 block range 59918524~91454523 (block count: 31536000)
// [INFO] halving year 5 block range 91454524~116683323 (block count: 25228800)
// [INFO] halving year 6 block range 116683324~127195323 (block count: 10512000)
// [INFO] halving year 7 block range 127195324~137707323 (block count: 10512000)
// [INFO] halving year 8 block range 137707324~148219323 (block count: 10512000)
// [INFO] halving year 9 block range 148219324~158731323 (block count: 10512000)
// [INFO] halving year 10 block range 158731324~169243323 (block count: 10512000)
// [INFO] halving year 11 block range 169243324~179755323 (block count: 10512000)
// [INFO] halving year 12 block range 179755324~190267323 (block count: 10512000)
//
// [SCENARIO] 10. Year 5: Mint after skipping remaining year (block time 3000ms)
// [INFO] current block height 116683323
// [EXPECTED] minted amount: 56250000000000
// [EXPECTED] total minted amount: 731250000000000
//
// [SCENARIO] 11. Year 6: Change block time to 2000ms at 40% of year, then mint at year end
// [INFO] current block height 120888123
// [INFO] block time changed to 2000ms
// [INFO] current year is 6
// [EXPECTED] end block height: 127195323 -> 130348923
// [EXPECTED] amount per block: 5351027 -> 5945585
//
// [SCENARIO] 12. Year 6: Get halving years
// [INFO] current halving year 6
// [INFO] average block time in ms 2000
// [INFO] halving year 1 block range 124~15768123 (block count: 15768000)
// [INFO] halving year 2 block range 15768124~31536123 (block count: 15768000)
// [INFO] halving year 3 block range 31536124~59918523 (block count: 28382400)
// [INFO] halving year 4 block range 59918524~91454523 (block count: 31536000)
// [INFO] halving year 5 block range 91454524~116683323 (block count: 25228800)
// [INFO] halving year 6 block range 116683324~130348923 (block count: 13665600)
// [INFO] halving year 7 block range 130348924~146116923 (block count: 15768000)
// [INFO] halving year 8 block range 146116924~161884923 (block count: 15768000)
// [INFO] halving year 9 block range 161884924~177652923 (block count: 15768000)
// [INFO] halving year 10 block range 177652924~193420923 (block count: 15768000)
// [INFO] halving year 11 block range 193420924~209188923 (block count: 15768000)
// [INFO] halving year 12 block range 209188924~224956923 (block count: 15768000)
//
// [SCENARIO] 13. Year 6: Mint after skipping remaining year (block time 2000ms)
// [INFO] current block height 130348923
// [EXPECTED] minted amount: 56250000000000
// [EXPECTED] total minted amount: 787500000000000
//
// [SCENARIO] 14. Year 7: Mint after skipping 1 year (block time 2000ms)
// [INFO] current block height 146116923
// [EXPECTED] minted amount: 28125000000000
// [EXPECTED] total minted amount: 815625000000000
//
// [SCENARIO] 15. Year 8: Mint after skipping 1 year (block time 2000ms)
// [INFO] current block height 161884923
// [EXPECTED] minted amount: 28125000000000
// [EXPECTED] total minted amount: 843750000000000
//
// [SCENARIO] 16. Year 9: Mint after skipping 1 year (block time 2000ms)
// [INFO] current block height 177652923
// [EXPECTED] minted amount: 14062500000000
// [EXPECTED] total minted amount: 857812500000000
//
// [SCENARIO] 17. Year 10: Change block time to 1000ms at 50% of year, then mint at year end
// [INFO] current block height 185536923
// [INFO] block time changed to 1000ms
// [INFO] current year is 10
// [EXPECTED] end block height: 193420923 -> 201304923
// [EXPECTED] amount per block: 891837 -> 891837
//
// [SCENARIO] 18. Year 10: Get halving years
// [INFO] current halving year 10
// [INFO] average block time in ms 1000
// [INFO] halving year 1 block range 124~15768123 (block count: 15768000)
// [INFO] halving year 2 block range 15768124~31536123 (block count: 15768000)
// [INFO] halving year 3 block range 31536124~59918523 (block count: 28382400)
// [INFO] halving year 4 block range 59918524~91454523 (block count: 31536000)
// [INFO] halving year 5 block range 91454524~116683323 (block count: 25228800)
// [INFO] halving year 6 block range 116683324~130348923 (block count: 13665600)
// [INFO] halving year 7 block range 130348924~146116923 (block count: 15768000)
// [INFO] halving year 8 block range 146116924~161884923 (block count: 15768000)
// [INFO] halving year 9 block range 161884924~177652923 (block count: 15768000)
// [INFO] halving year 10 block range 177652924~201304923 (block count: 23652000)
// [INFO] halving year 11 block range 201304924~232840923 (block count: 31536000)
// [INFO] halving year 12 block range 232840924~264376923 (block count: 31536000)
//
// [SCENARIO] 19. Year 10: Mint after skipping remaining year (block time 1000ms)
// [INFO] current block height 201304923
// [EXPECTED] minted amount: 14062500000000
// [EXPECTED] total minted amount: 871875000000000
//
// [SCENARIO] 20. Year 11: Mint after skipping 1 year (block time 1000ms)
// [INFO] current block height 232840923
// [EXPECTED] minted amount: 14062500000000
// [EXPECTED] total minted amount: 885937500000000
//
// [SCENARIO] 21. Year 12: Mint after skipping 1 year (block time 1000ms)
// [INFO] current block height 264376923
// [EXPECTED] minted amount: 14062500000000
// [EXPECTED] total minted amount: 900000000000000
