// verify minted gns remaining amount
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

	println("[SCENARIO] 2. Mint GNS when skipped 31536000 blocks (skip 2 years)")
	testing.SkipHeights(31536000)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 3. Mint GNS when skipped 12614400 blocks (40% of 3 year)")
	testing.SkipHeights(12614400)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 4. Change block time to 3000ms (2000ms -> 3000ms)")
	changeBlockTime(3000)
	println()

	println("[SCENARIO] 5. Verify minted GNS remaining amount")
	verifyMintedGNSRemainingAmount()
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

func verifyMintedGNSRemainingAmount() {
	currentBlockHeight := std.ChainHeight()
	currentYear := gns.GetHalvingYearByHeight(currentBlockHeight)
	remainingAmount := gns.GetHalvingYearMaxAmount(currentYear) - gns.GetHalvingYearMintAmount(currentYear)
	endBlockHeight := gns.GetHalvingYearEndBlock(currentYear)
	remainingBlockNum := endBlockHeight - currentBlockHeight

	remainingAmountPerBlock := remainingAmount / remainingBlockNum

	currentAmountPerBlock := gns.GetAmountPerBlockPerHalvingYear(currentYear)

	println("[INFO] current year", currentYear)
	println("[INFO] current block height", currentBlockHeight)
	println("[INFO] current year end block height", endBlockHeight)
	println("[INFO] remaining amount", remainingAmount)
	println("[INFO] remaining block num", remainingBlockNum)

	ufmt.Printf("[EXPECTED] amount per block should be %d (current amount per block: %d, calculated amount per block: %d)\n", remainingAmountPerBlock, currentAmountPerBlock, remainingAmountPerBlock)
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint GNS when skipped 31536000 blocks (skip 2 years)
// [INFO] current block height 31536123
// [EXPECTED] minted amount should be 450000000000000
// [EXPECTED] total minted amount should be 450000000000000
//
// [SCENARIO] 3. Mint GNS when skipped 12614400 blocks (40% of 3 year)
// [INFO] current block height 44150523
// [EXPECTED] minted amount should be 89999997523200
// [EXPECTED] total minted amount should be 539999997523200
//
// [SCENARIO] 4. Change block time to 3000ms (2000ms -> 3000ms)
// [INFO] current year is 3
// [EXPECTED] end block height should be changed 47304123 to 46252923
// [EXPECTED] amount per block should be changed 7134703 to 10702055
//
// [SCENARIO] 5. Verify minted GNS remaining amount
// [INFO] current year 3
// [INFO] current block height 44150523
// [INFO] current year end block height 46252923
// [INFO] remaining amount 22500002476800
// [INFO] remaining block num 2102400
// [EXPECTED] amount per block should be 10702055 (current amount per block: 10702055, calculated amount per block: 10702055)
