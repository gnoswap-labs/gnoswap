// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var t *testing.T

const (
	INT64_MAX int64 = 9223372036854775807
	swapFee         = uint64(15) // 0.15%
)

var (
	adminAddr, _  = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())
	routerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/v1/router")

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(500)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool with multiple positions")
	initPoolMultiPosition()
	println()

	testing.SkipHeights(1)

	ufmt.Println("[SCENARIO] 2. Test Exact In Swaps - DrySwap vs Actual Swap")
	testExactIn_Small()
	println()
	testExactIn_Medium()
	println()
	testExactIn_Large()
	println()
	testExactIn_AlmostAll()
	println()

	ufmt.Println("[SCENARIO] 3. Test Exact Out Swaps - DrySwap vs Actual Swap")
	testExactOut_Small()
	println()
	testExactOut_Medium()
	println()
	testExactOut_Large()
	println()
	testExactOut_BugScenario()
	println()

	ufmt.Println("[SCENARIO] 4. Test Edge Cases - Overflow Boundary")
	testExactOut_JustBelowOverflow()
	println()
	testExactOut_JustAtOverflow()
	println()

	ufmt.Println("[SCENARIO] 5. Test Additional Edge Cases")
	testZeroAmount()
	println()
	testReverseDirection()
	println()
	testMaxSlippage()
	println()
}

func initPoolMultiPosition() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	defaultTokenAmount := int64(100_000_000_000_000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)
	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Creating pool")
	pl.CreatePool(
		cross,
		barPath,
		fooPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	ufmt.Println("[INFO] Minting 6 positions (same as bug scenario)")
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	pn.Mint(cross, barPath, fooPath, fee, -6930, 6930, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	pn.Mint(cross, barPath, fooPath, fee, -6930, 6930, "3000000000", "3000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	pn.Mint(cross, barPath, fooPath, fee, -1050, 950, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	pn.Mint(cross, barPath, fooPath, fee, -887270, 887270, "5000000000", "5000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	pn.Mint(cross, barPath, fooPath, fee, -44260, -19070, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	pn.Mint(cross, barPath, fooPath, fee, 62160, 69060, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
}

// EXACT IN TESTS

func testExactIn_Small() {
	testing.SetRealm(aliceRealm)

	amount := "100000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Exact In - Small amount")
	dryIn, dryOut, _ := router.DrySwapRoute(
		barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross, barPath, routerAddr, 100000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactIn_Medium() {
	testing.SetRealm(aliceRealm)

	amount := "10000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Exact In - Medium amount")
	dryIn, dryOut, _ := router.DrySwapRoute(
		barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross, barPath, routerAddr, 10000000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactIn_Large() {
	testing.SetRealm(aliceRealm)

	amount := "1000000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Exact In - Large amount")
	dryIn, dryOut, _ := router.DrySwapRoute(
		barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross, barPath, routerAddr, 1000000000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactIn_AlmostAll() {
	testing.SetRealm(aliceRealm)

	amount := "100000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact In - Almost all liquidity")
	dryIn, dryOut, _ := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_IN", route, "100", "1",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross, fooPath, routerAddr, 100000000000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross, fooPath, barPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

// EXACT OUT TESTS

func testExactOut_Small() {
	testing.SetRealm(aliceRealm)

	amount := "100000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact Out - Small amount")
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if !drySuccess {
		return
	}

	common.SafeGRC20Approve(cross, fooPath, routerAddr, 999999999999)
	actualIn, actualOut := router.ExactOutSwapRoute(
		cross, fooPath, barPath, amount, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactOut_Medium() {
	testing.SetRealm(aliceRealm)

	amount := "10000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact Out - Medium amount")
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if !drySuccess {
		return
	}

	common.SafeGRC20Approve(cross, fooPath, routerAddr, 999999999999)
	actualIn, actualOut := router.ExactOutSwapRoute(
		cross, fooPath, barPath, amount, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactOut_Large() {
	testing.SetRealm(aliceRealm)

	amount := "1000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact Out - Large amount")
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if !drySuccess {
		return
	}

	common.SafeGRC20Approve(cross, fooPath, routerAddr, 999999999999)
	actualIn, actualOut := router.ExactOutSwapRoute(
		cross, fooPath, barPath, amount, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactOut_BugScenario() {
	testing.SetRealm(aliceRealm)

	amount := "10000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Bug Scenario - Large exact out")
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999999",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if drySuccess {
		common.SafeGRC20Approve(cross, fooPath, routerAddr, 999999999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross, fooPath, barPath, amount, route, "100", "999999999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
		ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
	}
}

func testExactOut_JustBelowOverflow() {
	testing.SetRealm(aliceRealm)

	amount := "10983000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing overflow boundary - amount 10983000000")
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999999",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)
}

func testExactOut_JustAtOverflow() {
	testing.SetRealm(aliceRealm)

	amount := "10982000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing overflow trigger - amount 10982000000")
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999999",
	)
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if drySuccess {
		ufmt.Println("[ERROR] DrySwap should have failed but succeeded!")
		common.SafeGRC20Approve(cross, fooPath, routerAddr, 999999999999999)
		uassert.AbortsWithMessage(t, "[GNOSWAP-POOL-026] overflow", func() {
			router.ExactOutSwapRoute(
				cross, fooPath, barPath, amount, route, "100", "999999999999999",
				time.Now().Add(time.Hour).Unix(), "",
			)
		})
	}
}

// Additional Edge Case Tests

func testZeroAmount() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing zero amount swap")

	// Test exact in with zero
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		barPath, fooPath, "0", "EXACT_IN", "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "1",
	)
	ufmt.Printf("[EXPECTED] Zero exact in - DrySwap should return in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	// Test exact out with zero
	dryIn2, dryOut2, drySuccess2 := router.DrySwapRoute(
		barPath, fooPath, "0", "EXACT_OUT", "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "999999999999",
	)
	ufmt.Printf("[EXPECTED] Zero exact out - DrySwap should return in=%s out=%s success=%t\n", dryIn2, dryOut2, drySuccess2)
}

func testReverseDirection() {
	testing.SetRealm(aliceRealm)

	amount := "1000000"

	ufmt.Println("[INFO] Testing reverse direction swap consistency")

	// Forward: BAR -> FOO
	dryInFwd, dryOutFwd, _ := router.DrySwapRoute(
		barPath, fooPath, amount, "EXACT_IN", "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "1",
	)
	common.SafeGRC20Approve(cross, barPath, routerAddr, 1000000)
	actualInFwd, actualOutFwd := router.ExactInSwapRoute(
		cross, barPath, fooPath, amount, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Forward swap - Dry: in=%s out(with fee)=%s | Actual: in=%s out=%s\n",
		dryInFwd, dryOutFwd, actualInFwd, actualOutFwd)

	// Reverse: FOO -> BAR
	dryInRev, dryOutRev, _ := router.DrySwapRoute(
		fooPath, barPath, amount, "EXACT_IN", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1",
	)

	common.SafeGRC20Approve(cross, fooPath, routerAddr, 1000000)
	actualInRev, actualOutRev := router.ExactInSwapRoute(
		cross, fooPath, barPath, amount, "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Reverse swap - Dry: in=%s out(with fee)=%s | Actual: in=%s out=%s\n",
		dryInRev, dryOutRev, actualInRev, actualOutRev)
}

func testMaxSlippage() {
	testing.SetRealm(aliceRealm)

	amount := "1000000"

	ufmt.Println("[INFO] Testing with maximum slippage protection")

	// Test with very tight slippage (should fail)
	dryIn, dryOut, drySuccess := router.DrySwapRoute(
		barPath, fooPath, amount, "EXACT_IN", "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "999999",
	)
	ufmt.Printf("[EXPECTED] Tight slippage - DrySwap returns in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	if drySuccess {
		// This means the swap would succeed, verify with actual swap
		common.SafeGRC20Approve(cross, barPath, routerAddr, 1000000)
		actualIn, actualOut := router.ExactInSwapRoute(
			cross, barPath, fooPath, amount, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Swap - Dry: in=%s out(with fee)=%s | Actual: in=%s out(with fee)=%s\n",
			dryIn, dryOut, actualIn, actualOut)
	}
}

// Output:
// [SCENARIO] 1. Initialize pool with multiple positions
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Creating pool
// [INFO] Minting 6 positions (same as bug scenario)
//
// [SCENARIO] 2. Test Exact In Swaps - DrySwap vs Actual Swap
// [INFO] Testing Exact In - Small amount
// [EXPECTED] DrySwap amountIn should be 100000
// [EXPECTED] DrySwap amountOut should be 99800
// [EXPECTED] Actual amountIn should be 100000
// [EXPECTED] Actual amountOut should be -99800
//
// [INFO] Testing Exact In - Medium amount
// [EXPECTED] DrySwap amountIn should be 10000000
// [EXPECTED] DrySwap amountOut should be 9977346
// [EXPECTED] Actual amountIn should be 10000000
// [EXPECTED] Actual amountOut should be -9977346
//
// [INFO] Testing Exact In - Large amount
// [EXPECTED] DrySwap amountIn should be 1000000000
// [EXPECTED] DrySwap amountOut should be 972055147
// [EXPECTED] Actual amountIn should be 1000000000
// [EXPECTED] Actual amountOut should be -972055147
//
// [INFO] Testing Exact In - Almost all liquidity
// [EXPECTED] DrySwap amountIn should be 100000000000
// [EXPECTED] DrySwap amountOut should be 10643831036
// [EXPECTED] Actual amountIn should be 100000000000
// [EXPECTED] Actual amountOut should be -10643831036
//
// [SCENARIO] 3. Test Exact Out Swaps - DrySwap vs Actual Swap
// [INFO] Testing Exact Out - Small amount
// [EXPECTED] DrySwap amountIn should be 38005732
// [EXPECTED] DrySwap amountOut should be 100000
// [EXPECTED] DrySwap success should be true
// [EXPECTED] Actual amountIn should be 38005732
// [EXPECTED] Actual amountOut should be -100000
//
// [INFO] Testing Exact Out - Medium amount
// [EXPECTED] DrySwap amountIn should be 3956433712
// [EXPECTED] DrySwap amountOut should be 10000000
// [EXPECTED] DrySwap success should be true
// [EXPECTED] Actual amountIn should be 3956433712
// [EXPECTED] Actual amountOut should be -10000000
//
// [INFO] Testing Exact Out - Large amount
// [EXPECTED] DrySwap amountIn should be 679799534408
// [EXPECTED] DrySwap amountOut should be 1000000000
// [EXPECTED] DrySwap success should be true
// [EXPECTED] Actual amountIn should be 679799534408
// [EXPECTED] Actual amountOut should be -1000000000
//
// [INFO] Testing Bug Scenario - Large exact out
// [EXPECTED] DrySwap amountIn should be 0
// [EXPECTED] DrySwap amountOut should be 0
// [EXPECTED] DrySwap success should be false
//
// [SCENARIO] 4. Test Edge Cases - Overflow Boundary
// [INFO] Testing overflow boundary - amount 10983000000
// [EXPECTED] DrySwap amountIn should be 0
// [EXPECTED] DrySwap amountOut should be 0
// [EXPECTED] DrySwap success should be false
//
// [INFO] Testing overflow trigger - amount 10982000000
// [EXPECTED] DrySwap amountIn should be 0
// [EXPECTED] DrySwap amountOut should be 0
// [EXPECTED] DrySwap success should be false
//
// [SCENARIO] 5. Test Additional Edge Cases
// [INFO] Testing zero amount swap
// [EXPECTED] Zero exact in - DrySwap should return in=0 out=0 success=false
// [EXPECTED] Zero exact out - DrySwap should return in=0 out=0 success=false
//
// [INFO] Testing reverse direction swap consistency
// [EXPECTED] Forward swap - Dry: in=1000000 out(with fee)=931857046 | Actual: in=1000000 out=-931857046
// [EXPECTED] Reverse swap - Dry: in=1000000 out(with fee)=1069 | Actual: in=1000000 out=-1069
//
// [INFO] Testing with maximum slippage protection
// [EXPECTED] Tight slippage - DrySwap returns in=1000000 out=931161307 success=true
// [EXPECTED] Swap - Dry: in=1000000 out(with fee)=931161307 | Actual: in=1000000 out(with fee)=-931161307
