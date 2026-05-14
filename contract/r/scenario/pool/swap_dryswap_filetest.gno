// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
)

// Constants for fee tiers
const (
	fee500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
)

var (
	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = "100000000"

	poolCreationFee = int64(100_000_000)

	MIN_PRICE string = "4295128740"
)

func main() {
	// call gns faucet to get creation fee
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

	println("[SCENARIO] 1. DrySwap ZeroForOne True AmountSpecified Positive 16000")
	TestDrySwap_ZeroForOneTrue_AmountSpecified_Positive_16000()
	println()

	println("[SCENARIO] 2. DrySwap ZeroForOne True AmountSpecified Negative 16000")
	TestDrySwap_ZeroForOneTrue_AmountSpecified_Negative_16000()
	println()

	println("[INFO] Passed all tests")
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Positive_16000() {
	testing.SetRealm(posRealm)

	// no mint == no liquidity => swap will fail
	pool.DrySwap(btcPath, atomPath, fee500, true, "16000", MIN_PRICE)

	// not enough mint == swap will fail
	testing.SetRealm(adminRealm)

	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	pool.DrySwap(btcPath, atomPath, fee500, true, "16000", MIN_PRICE)

	testing.SetRealm(adminRealm)

	testing.SetRealm(posRealm)
	pool.Mint(cross, btcPath, atomPath, fee500, -tickUpper, -tickLower, liquidityExpect, adminAddr) // -11000  ~ -9000

	println("[INFO] dry swap")
	println("[INFO] zeroForOne true, amountSpecified 16000")
	poolIn, poolOut, _ := pool.DrySwap(
		btcPath,   // btcPath
		atomPath,   // atomPath
		fee500,    // fee500
		true,      // zeroForOne
		"16000",   // amountSpecified
		MIN_PRICE, // sqrtPriceLimitX96
	)
	println("[EXPECTED] poolIn:", poolIn, "expected: should be 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: should be -5883")
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Negative_16000() {
	println("[INFO] zeroForOne true, amountSpecified -16000")

	poolIn, poolOut, _ := pool.DrySwap(
		btcPath,   // btcPath
		atomPath,   // atomPath
		fee500,    // fee500
		true,      // zeroForOne
		"-16000",  // amountSpecified
		MIN_PRICE, // sqrtPriceLimitX96
	)

	println("[EXPECTED] poolIn:", poolIn, "expected: should be 43513")
	println("[EXPECTED] poolOut:", poolOut, "expected: should be -16000")
}

// Output:
// [SCENARIO] 1. DrySwap ZeroForOne True AmountSpecified Positive 16000
// [INFO] dry swap
// [INFO] zeroForOne true, amountSpecified 16000
// [EXPECTED] poolIn: 16000 expected: should be 16000
// [EXPECTED] poolOut: -5882 expected: should be -5883
//
// [SCENARIO] 2. DrySwap ZeroForOne True AmountSpecified Negative 16000
// [INFO] zeroForOne true, amountSpecified -16000
// [EXPECTED] poolIn: 43524 expected: should be 43513
// [EXPECTED] poolOut: -16000 expected: should be -16000
//
// [INFO] Passed all tests
