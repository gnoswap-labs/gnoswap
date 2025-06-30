// mint gns by skipping blocks
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"

	_ "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/gnoswap/v1/access"
)

var t *testing.T

var (
	user01Addr  = testutils.TestAddress("user01Addr")
	user01Realm = std.NewUserRealm(user01Addr)

	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize emission callback")
	initEmissionCallback()
	println()

	ufmt.Println("[SCENARIO] 2. Mint GNS when initialized")
	mintGNS()
	println()

	ufmt.Println("[SCENARIO] 3. Skip 50 blocks")
	testing.SkipHeights(50)
	println()

	ufmt.Println("[SCENARIO] 4. Mint GNS when skipped 50 blocks")
	mintGNS()
}

func initEmissionCallback() {

}

func mintGNS() {
	testing.SetRealm(std.NewCodeRealm(consts.EMISSION_PATH))

	mintedAmount := gns.MintGns(cross, user01Addr)

	ufmt.Printf("[EXPECTED] minted amount should be %d\n", mintedAmount)
}

// Output:
// [SCENARIO] 1. Initialize emission callback
//
// [SCENARIO] 2. Mint GNS when initialized
// [EXPECTED] minted amount should be 0
//
// [SCENARIO] 3. Skip 50 blocks
//
// [SCENARIO] 4. Mint GNS when skipped 50 blocks
// [EXPECTED] minted amount should be 713470300
