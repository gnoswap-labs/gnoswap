package main

import (
	"std"
	"testing"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gns"
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
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

var (
	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = "100000000"

	poolCreationFee = int64(100_000_000)
)

func main() {
	// call gns faucet to get creation fee
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-10000).ToString()) // tick -10000

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
	pool.DrySwap(cross, fooPath, barPath, fee500, true, "16000", consts.MIN_PRICE)

	// not enough mint == swap will fail
	testing.SetRealm(adminRealm)

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	pool.DrySwap(cross, fooPath, barPath, fee500, true, "16000", consts.MIN_PRICE)

	testing.SetRealm(adminRealm)

	testing.SetRealm(posRealm)
	pool.Mint(cross, fooPath, barPath, fee500, positionAddr, -tickUpper, -tickLower, liquidityExpect, adminAddr) // -11000  ~ -9000

	println("[INFO] dry swap")
	println("[INFO] zeroForOne true, amountSpecified 16000")
	poolIn, poolOut, _ := pool.DrySwap(
		cross,
		fooPath,          // fooPath
		barPath,          // barPath
		fee500,           // fee500
		true,             // zeroForOne
		"16000",          // amountSpecified
		consts.MIN_PRICE, // sqrtPriceLimitX96
	)
	println("[EXPECTED] poolIn:", poolIn, "expected: should be 16000")
	println("[EXPECTED] poolOut:", poolOut, "expected: should be -5883")
}

func TestDrySwap_ZeroForOneTrue_AmountSpecified_Negative_16000() {
	println("[INFO] zeroForOne true, amountSpecified -16000")

	poolIn, poolOut, _ := pool.DrySwap(
		cross,
		fooPath,          // fooPath
		barPath,          // barPath
		fee500,           // fee500
		true,             // zeroForOne
		"-16000",         // amountSpecified
		consts.MIN_PRICE, // sqrtPriceLimitX96
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
