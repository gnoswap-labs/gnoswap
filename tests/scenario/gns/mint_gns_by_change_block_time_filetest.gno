// mint gns by change block time
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"

	"gno.land/r/gnoswap/v1/access"
)

var t *testing.T

var (
	user01Addr  = testutils.TestAddress("user01Addr")
	user01Realm = std.NewUserRealm(user01Addr)

	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
)

const (
	milliSecondsOfYear = 31536000000 // 365 * 24 * 60 * 60 * 1000
	defaultBlockTime   = 2000        // 2000ms
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	ufmt.Println("[SCENARIO] 2. Mint GNS when initialized")
	ufmt.Println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	// 15768000 blocks = 31536000000ms / 2000ms
	println("[SCENARIO] 3. Mint GNS when skipped 15767999 blocks (distribute of 1 year - 1 block)")
	testing.SkipHeights(15767999)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 4. Mint GNS when skipped 1 block (distribute all of 1 year)")
	testing.SkipHeights(1)
	println("[INFO] current block height", std.ChainHeight())
	println("[INFO] last block minted amount is reward amount per block with left emission amount by not distributed of a year")
	mintGNS()
	println()

	println("[SCENARIO] 5. Mint GNS when skipped 1 block (start of 2nd year)")
	testing.SkipHeights(1)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	// remain end block time is 15767999 blocks * 2000ms = 31535998000
	// expect change remain block height is 7883999
	println("[SCENARIO] 6. Change block time to 4000ms (2000ms -> 4000ms)")
	changeBlockTime(4000)
	println()

	// expect amount per block is 28538814, (225000000000000 - 14269406) / 7883999 = 28538814
	println("[SCENARIO] 7. Mint GNS when skipped 1 block (expect amount per block is 28538814)")
	testing.SkipHeights(1)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	// total minted amount include 2nd year left emission amount
	println("[SCENARIO] 8. Mint GNS when skipped 7883998 block then 2nd year end (expect total minted amount is 450000000000000)")
	testing.SkipHeights(7883998)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 9. Mint GNS when skipped 1 block (expect amount per block is 14269406)")
	testing.SkipHeights(1)
	println("[INFO] current block height", std.ChainHeight())
	mintGNS()
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

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint GNS when initialized
// [INFO] current block height 123
// [EXPECTED] minted amount should be 0
// [EXPECTED] total minted amount should be 0
//
// [SCENARIO] 3. Mint GNS when skipped 15767999 blocks (distribute of 1 year - 1 block)
// [INFO] current block height 15768122
// [EXPECTED] minted amount should be 224999979538594
// [EXPECTED] total minted amount should be 224999979538594
//
// [SCENARIO] 4. Mint GNS when skipped 1 block (distribute all of 1 year)
// [INFO] current block height 15768123
// [INFO] last block minted amount is reward amount per block with left emission amount by not distributed of a year
// [EXPECTED] minted amount should be 20461406
// [EXPECTED] total minted amount should be 225000000000000
//
// [SCENARIO] 5. Mint GNS when skipped 1 block (start of 2nd year)
// [INFO] current block height 15768124
// [EXPECTED] minted amount should be 14269406
// [EXPECTED] total minted amount should be 225000014269406
//
// [SCENARIO] 6. Change block time to 4000ms (2000ms -> 4000ms)
// [INFO] current year is 2
// [EXPECTED] end block height should be changed 31536123 to 23652123
// [EXPECTED] amount per block should be changed 14269406 to 28538814
//
// [SCENARIO] 7. Mint GNS when skipped 1 block (expect amount per block is 28538814)
// [INFO] current block height 15768125
// [EXPECTED] minted amount should be 28538814
// [EXPECTED] total minted amount should be 225000042808220
//
// [SCENARIO] 8. Mint GNS when skipped 7883998 block then 2nd year end (expect total minted amount is 450000000000000)
// [INFO] current block height 23652123
// [EXPECTED] minted amount should be 224999957191780
// [EXPECTED] total minted amount should be 450000000000000
//
// [SCENARIO] 9. Mint GNS when skipped 1 block (expect amount per block is 14269406)
// [INFO] current block height 23652124
// [EXPECTED] minted amount should be 14269406
// [EXPECTED] total minted amount should be 450000014269406
