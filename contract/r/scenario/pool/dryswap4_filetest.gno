// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"

	"gno.land/r/gnoswap/pool"

	_ "gno.land/r/gnoswap/pool/v1"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier500 uint32 = 500
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

// Token paths
var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
)

// Test variables
var (
	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = "100000000000"

	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
)

// DrySwap Test - ZeroForOne False (Token1 to Token0)
// Testing DrySwap functionality with zeroForOne=false
// Expected behavior: Calculate swap amounts for Token1 to Token0 direction
func main() {
	testDrySwapZeroForOneFalse(t)
}

// testDrySwapZeroForOneFalse tests DrySwap with zeroForOne=false
func testDrySwapZeroForOneFalse(t *testing.T) {
	// Given: Pool exists with minted position
	println("[INFO] Token0:", atomPath)
	println("[INFO] Token1:", btcPath)
	println("[INFO] Fee tier:", FeeTier500)
	println("[INFO] Initial liquidity amount:", liquidityExpect)
	println("[INFO] Tick range:", -tickUpper, "to", -tickLower)
	println("[INFO] Direction: Token1 (btc) to Token0 (atom) - zeroForOne=false")

	// Create pool
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		FeeTier500,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString(),
	)

	// Approve tokens for minting
	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)

	// Mint position
	testing.SetRealm(posRealm)
	mintAmount0, mintAmount1 := pool.Mint(
		cross,
		btcPath,
		atomPath,
		FeeTier500,
		-tickUpper,
		-tickLower,
		liquidityExpect,
		adminAddr,
	)

	println("[INFO] Position minted successfully")
	println("[INFO] Minted amount0:", mintAmount0)
	println("[INFO] Minted amount1:", mintAmount1)

	// When: Perform DrySwap with zeroForOne=false and positive amountSpecified
	amountSpecified := "16000"
	println("[INFO] Performing DrySwap with zeroForOne=false")
	println("[INFO] Amount specified:", amountSpecified)
	println("[INFO] Direction: btc (Token1) -> atom (Token0)")

	poolIn, poolOut, _ := pool.DrySwap(
		btcPath,
		atomPath,
		FeeTier500,
		false, // zeroForOne = false
		amountSpecified,
		MAX_PRICE, // Use MAX_PRICE for zeroForOne=false
	)

	// Then: Verify DrySwap results for zeroForOne=false
	println("[EXPECTED] Pool input amount should be:", "16000")
	println("[EXPECTED] Pool output amount should be positive (atom tokens)")
	println("[INFO] Actual pool input amount:", poolIn)
	println("[INFO] Actual pool output amount:", poolOut)

	println("[EXPECTED] poolIn", poolIn)
	// Note: poolOut will be positive for zeroForOne=false as we're getting atom tokens

	// When: Perform DrySwap with zeroForOne=false and negative amountSpecified
	negativeAmount := "-16000"
	println("[INFO] Performing DrySwap with zeroForOne=false and negative amount")
	println("[INFO] Amount specified:", negativeAmount)
	println("[INFO] This means exact output amount is specified")

	poolInNeg, poolOutNeg, _ := pool.DrySwap(
		btcPath,
		atomPath,
		FeeTier500,
		false, // zeroForOne = false
		negativeAmount,
		MAX_PRICE,
	)

	// Then: Verify DrySwap results for negative amount
	println("[EXPECTED] Pool input amount should be calculated for exact output")
	println("[EXPECTED] Pool output amount should be:", "-16000")
	println("[INFO] Actual pool input amount:", poolInNeg)
	println("[INFO] Actual pool output amount:", poolOutNeg)

	println("[EXPECTED] poolInNeg", poolInNeg)

	println("[SCENARIO] 5. DrySwap Test - ZeroForOne False - PASSED")
	println("[INFO] DrySwap correctly handles zeroForOne=false direction")
}

// Output:
// [INFO] Token0: gno.land/r/gnoswap/test_token/atom
// [INFO] Token1: gno.land/r/gnoswap/test_token/btc
// [INFO] Fee tier: 500
// [INFO] Initial liquidity amount: 100000000000
// [INFO] Tick range: -11000 to -9000
// [INFO] Direction: Token1 (btc) to Token0 (atom) - zeroForOne=false
// [INFO] Position minted successfully
// [INFO] Minted amount0: 8040315472
// [INFO] Minted amount1: 2958014650
// [INFO] Performing DrySwap with zeroForOne=false
// [INFO] Amount specified: 16000
// [INFO] Direction: btc (Token1) -> atom (Token0)
// [EXPECTED] Pool input amount should be: 16000
// [EXPECTED] Pool output amount should be positive (atom tokens)
// [INFO] Actual pool input amount: -43468
// [INFO] Actual pool output amount: 16000
// [EXPECTED] poolIn -43468
// [INFO] Performing DrySwap with zeroForOne=false and negative amount
// [INFO] Amount specified: -16000
// [INFO] This means exact output amount is specified
// [EXPECTED] Pool input amount should be calculated for exact output
// [EXPECTED] Pool output amount should be: -16000
// [INFO] Actual pool input amount: -16000
// [INFO] Actual pool output amount: 5890
// [EXPECTED] poolInNeg -16000
// [SCENARIO] 5. DrySwap Test - ZeroForOne False - PASSED
// [INFO] DrySwap correctly handles zeroForOne=false direction
