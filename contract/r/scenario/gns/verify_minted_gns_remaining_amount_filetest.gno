// verify minted gns remaining amount
package main

import (
	"chain/runtime"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
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
	println("[SCENARIO] 1. Initialize emission")
	initEmission()
	println()

	println("[SCENARIO] 2. Mint GNS when skipped 31536000 blocks (skip 2 years)")
	testing.SkipHeights(31536000)
	println("[INFO] current block height", runtime.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 3. Mint GNS when skipped 12614400 blocks (40% of 3 year)")
	testing.SkipHeights(12614400)
	println("[INFO] current block height", runtime.ChainHeight())
	mintGNS()
	println()

	println("[SCENARIO] 4. Verify minted GNS remaining amount")
	verifyMintedGNSRemainingAmount()
	println()
}

func initEmission() {}

func mintGNS() {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/emission"))

	mintedAmount := gns.MintGns(cross, user01Addr)

	totalMintedAmount := gns.MintedEmissionAmount()

	ufmt.Printf("[EXPECTED] minted amount should be %d\n", mintedAmount)
	ufmt.Printf("[EXPECTED] total minted amount should be %d\n", totalMintedAmount)
}

func verifyMintedGNSRemainingAmount() {
	currentYear := gns.GetHalvingYear(time.Now().Unix())
	remainingAmount := gns.GetHalvingYearMaxAmount(currentYear) - gns.GetHalvingYearMintAmount(currentYear)
	endBlockTime := gns.GetHalvingYearEndTimestamp(currentYear)
	remainingBlockTime := endBlockTime - time.Now().Unix()

	remainingAmountPerBlock := remainingAmount / remainingBlockTime

	currentAmountPerBlock := gns.GetAmountPerSecondPerHalvingYear(currentYear)

	println("[INFO] current year", currentYear)
	println("[INFO] current block time", time.Now().Unix())
	println("[INFO] current year end block time", endBlockTime)
	println("[INFO] remaining amount", remainingAmount)
	println("[INFO] remaining block time", remainingBlockTime)

	ufmt.Printf("[EXPECTED] amount per block should be %d (current amount per block: %d, calculated amount per block: %d)\n", remainingAmountPerBlock, currentAmountPerBlock, remainingAmountPerBlock)
}

// Output:
// [SCENARIO] 1. Initialize emission
//
// [SCENARIO] 2. Mint GNS when skipped 31536000 blocks (skip 2 years)
// [INFO] current block height 31536123
// [EXPECTED] minted amount should be 900000000000000
// [EXPECTED] total minted amount should be 900000000000000
//
// [SCENARIO] 3. Mint GNS when skipped 12614400 blocks (40% of 3 year)
// [INFO] current block height 44150523
// [EXPECTED] minted amount should be 0
// [EXPECTED] total minted amount should be 900000000000000
//
// [SCENARIO] 4. Verify minted GNS remaining amount
// [INFO] current year 0
// [INFO] current block time 1455319890
// [INFO] current year end block time 0
// [INFO] remaining amount 0
// [INFO] remaining block time -1455319890
// [EXPECTED] amount per block should be 0 (current amount per block: 0, calculated amount per block: 0)
