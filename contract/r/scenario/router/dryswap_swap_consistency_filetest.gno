// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/qux"
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
	routerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/router")

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"
	fee     = uint32(500)
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] 1. Initialize pool with multiple positions")
	initPoolMultiPosition(cur)
	println()

	testing.SkipHeights(1)

	ufmt.Println("[SCENARIO] 2. Test Exact In Swaps - DrySwap vs Actual Swap")
	testExactIn_Small(cur)
	println()
	testExactIn_Medium(cur)
	println()
	testExactIn_Large(cur)
	println()
	testExactIn_AlmostAll(cur)
	println()

	ufmt.Println("[SCENARIO] 3. Test Exact Out Swaps - DrySwap vs Actual Swap")
	testExactOut_Small(cur)
	println()
	testExactOut_Medium(cur)
	println()
	testExactOut_Large(cur)
	println()
	testExactOut_BugScenario(cur)
	println()

	ufmt.Println("[SCENARIO] 4. Test Edge Cases - Overflow Boundary")
	testExactOut_JustBelowOverflow(cur)
	println()
	testExactOut_JustAtOverflow(cur)
	println()

	ufmt.Println("[SCENARIO] 5. Test Additional Edge Cases")
	testZeroAmount(cur)
	println()
	testReverseDirection(cur)
	println()
	testMaxSlippage(cur)
	println()

	ufmt.Println("[SCENARIO] 6. Test Multi-Hop Routes")
	ufmt.Println("[INFO] 2-hop single-route matrix")
	testMultiHop_TwoHop_ExactIn_Success(cur)
	println()
	testMultiHop_TwoHop_ExactOut_Success(cur)
	println()
	testMultiHop_TwoHop_ExactOut_Fail(cur)
	println()

	ufmt.Println("[INFO] 2-hop two-route matrix")
	testMultiHop_TwoRoute_TwoHop_ExactIn(cur)
	println()
	testMultiHop_TwoRoute_TwoHop_ExactOut_Success(cur)
	println()
	testMultiHop_TwoRoute_TwoHop_ExactOut_Fail(cur)
	println()

	ufmt.Println("[INFO] 3-hop single-route matrix")
	testMultiHop_ThreeHop_ExactIn_Success(cur)
	println()
	testMultiHop_ThreeHop_ExactOut_Success(cur)
	println()
	testMultiHop_ThreeHop_ExactOut_Fail(cur)
	println()

	ufmt.Println("[INFO] 3-hop two-route matrix")
	testMultiHop_TwoRoute_ThreeHop_ExactIn(cur)
	println()
	testMultiHop_TwoRoute_ThreeHop_ExactOut_Success(cur)
	println()
	testMultiHop_TwoRoute_ThreeHop_ExactOut_Fail(cur)
	println()
}

func initPoolMultiPosition(cur realm) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)

	defaultTokenAmount := int64(100_000_000_000_000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	ufmt.Println("[INFO] Distributing Baz tokens")
	baz.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	ufmt.Println("[INFO] Distributing Qux tokens")
	qux.Transfer(cross(cur), aliceAddr, defaultTokenAmount)

	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	baz.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)
	qux.Approve(cross(cur), poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Creating pool")
	pl.CreatePool(
		cross(cur),
		barPath,
		fooPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	pl.CreatePool(
		cross(cur),
		barPath,
		bazPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(10000).ToString(),
	)
	pl.CreatePool(
		cross(cur),
		bazPath,
		fooPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	pl.CreatePool(
		cross(cur),
		fooPath,
		quxPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	pl.CreatePool(
		cross(cur),
		barPath,
		quxPath,
		fee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	ufmt.Println("[INFO] Minting 6 positions (same as bug scenario)")
	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	baz.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)
	qux.Approve(cross(cur), poolAddr, INT64_MAX)

	pn.Mint(cross(cur), barPath, fooPath, fee, -6930, 6930, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee, -6930, 6930, "3000000000", "3000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee, -1050, 950, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee, -887270, 887270, "5000000000", "5000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee, -44260, -19070, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee, 62160, 69060, "1000000000", "1000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, bazPath, fee, 9000, 11000, "5000000000000", "5000000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), bazPath, fooPath, fee, -1000, 1000, "5000000000000", "5000000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), fooPath, quxPath, fee, -1000, 1000, "5000000000000", "5000000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, quxPath, fee, -1000, 1000, "5000000000000", "5000000000000", "0", "0", time.Now().Unix()+3600, aliceAddr, "")
}

// EXACT IN TESTS

func testExactIn_Small(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "100000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Exact In - Small amount")
	dryIn, dryOut, _ := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 100000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactIn_Medium(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Exact In - Medium amount")
	dryIn, dryOut, _ := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 10000000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactIn_Large(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "1000000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Exact In - Large amount")
	dryIn, dryOut, _ := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 1000000000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactIn_AlmostAll(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "100000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact In - Almost all liquidity")
	dryIn, dryOut, _ := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_IN", route, "100", "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)

	common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 100000000000)
	actualIn, actualOut := router.ExactInSwapRoute(
		cross(cur), fooPath, barPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

// EXACT OUT TESTS

func testExactOut_Small(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "100000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact Out - Small amount")
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if !drySuccess {
		return
	}

	common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 999999999999)
	actualIn, actualOut := router.ExactOutSwapRoute(
		cross(cur), fooPath, barPath, amount, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactOut_Medium(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact Out - Medium amount")
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if !drySuccess {
		return
	}

	common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 999999999999)
	actualIn, actualOut := router.ExactOutSwapRoute(
		cross(cur), fooPath, barPath, amount, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactOut_Large(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "1000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Exact Out - Large amount")
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if !drySuccess {
		return
	}

	common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 999999999999)
	actualIn, actualOut := router.ExactOutSwapRoute(
		cross(cur), fooPath, barPath, amount, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
	ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
}

func testExactOut_BugScenario(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing Bug Scenario - Large exact out")
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 999999999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), fooPath, barPath, amount, route, "100", "999999999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual amountIn should be %s\n", actualIn)
		ufmt.Printf("[EXPECTED] Actual amountOut should be %s\n", actualOut)
	}
}

func testExactOut_JustBelowOverflow(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10983000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing overflow boundary - amount 10983000000")
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)
}

func testExactOut_JustAtOverflow(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10982000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	ufmt.Println("[INFO] Testing overflow trigger - amount 10982000000")
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_OUT", route, "100", "999999999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap amountIn should be %s\n", dryIn)
	ufmt.Printf("[EXPECTED] DrySwap amountOut should be %s\n", dryOut)
	ufmt.Printf("[EXPECTED] DrySwap success should be %t\n", drySuccess)

	if drySuccess {
		ufmt.Println("[ERROR] DrySwap should have failed but succeeded!")
		common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 999999999999999)
		uassert.AbortsWithMessage(t, cur, "[GNOSWAP-POOL-020] overflow", func() {
			router.ExactOutSwapRoute(
				cross(cur), fooPath, barPath, amount, route, "100", "999999999999999",
				time.Now().Add(time.Hour).Unix(), "",
			)
		})
	}
}

// Additional Edge Case Tests

func testZeroAmount(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing zero amount validation")

	// Test exact in with zero - should abort
	result := uassert.AbortsContains(t, cur, "must be positive", func() {
		func(cur realm) {
			router.DrySwapRoute(
				barPath, fooPath, "0", "EXACT_IN",
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "1",
			)
		}(cross(cur))
	})
	if result {
		ufmt.Println("[EXPECTED] Zero exact in - Correctly aborted with expected message")
	} else {
		panic("[FAIL] Zero exact in - Did not abort as expected")
	}

	// Test exact out with zero - should abort
	result = uassert.AbortsContains(t, cur, "must be positive", func() {
		func(cur realm) {
			router.DrySwapRoute(
				barPath, fooPath, "0", "EXACT_OUT",
				"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "999999999999",
			)
		}(cross(cur))
	})
	if result {
		ufmt.Println("[EXPECTED] Zero exact out - Correctly aborted with expected message")
	} else {
		panic("[FAIL] Zero exact out - Did not abort as expected")
	}
}

func testReverseDirection(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "1000000"

	ufmt.Println("[INFO] Testing reverse direction swap consistency")

	// Forward: BAR -> FOO
	dryInFwd, dryOutFwd, _ := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "1",
		)
	}(cross(cur))
	common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 1000000)
	actualInFwd, actualOutFwd := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Forward swap - Dry: in=%s out(with fee)=%s | Actual: in=%s out=%s\n",
		dryInFwd, dryOutFwd, actualInFwd, actualOutFwd)

	// Reverse: FOO -> BAR
	dryInRev, dryOutRev, _ := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			fooPath, barPath, amount, "EXACT_IN", "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1",
		)
	}(cross(cur))

	common.SafeGRC20Approve(cross(cur), fooPath, routerAddr, 1000000)
	actualInRev, actualOutRev := router.ExactInSwapRoute(
		cross(cur), fooPath, barPath, amount, "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	ufmt.Printf("[EXPECTED] Reverse swap - Dry: in=%s out(with fee)=%s | Actual: in=%s out=%s\n",
		dryInRev, dryOutRev, actualInRev, actualOutRev)
}

func testMaxSlippage(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "1000000"

	ufmt.Println("[INFO] Testing with maximum slippage protection")

	// Test with very tight slippage (should fail)
	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] Tight slippage - DrySwap returns in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	if drySuccess {
		// This means the swap would succeed, verify with actual swap
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 1000000)
		actualIn, actualOut := router.ExactInSwapRoute(
			cross(cur), barPath, fooPath, amount, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", "100", "999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Swap - Dry: in=%s out(with fee)=%s | Actual: in=%s out(with fee)=%s\n",
			dryIn, dryOut, actualIn, actualOut)
	}
}

func parseInt64(cur realm, value string) (int64, bool) {
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, false
	}

	return parsed, true
}

func absInt64(cur realm, value int64) int64 {
	if value < 0 {
		return -value
	}

	return value
}

func printExactOutTolerance(cur realm, requested string, dryOut string, tolerance int64) {
	requestedAmount, okRequested := parseInt64(cur, requested)
	dryOutAmount, okDryOut := parseInt64(cur, dryOut)

	if !okRequested || !okDryOut {
		ufmt.Printf("[EXPECTED] ExactOut tolerance check: requested=%s dryOut=%s tolerance=%d parseError=true\n", requested, dryOut, tolerance)
		return
	}

	diff := absInt64(cur, requestedAmount-dryOutAmount)
	withinTolerance := diff <= tolerance

	ufmt.Printf("[EXPECTED] ExactOut tolerance check: requested=%s dryOut=%s diff=%d tolerance=%d withinTolerance=%t\n", requested, dryOut, diff, tolerance, withinTolerance)
}

func drySwapExactOutForAmount(cur realm, inputToken, outputToken string, amount int64, route, quote, amountLimit string) (string, bool, int64, bool) {
	amountStr := strconv.FormatInt(amount, 10)
	_, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			inputToken, outputToken, amountStr, "EXACT_OUT", route, quote, amountLimit,
		)
	}(cross(cur))

	dryOutAmount, okDryOut := parseInt64(cur, dryOut)
	if !okDryOut {
		return dryOut, drySuccess, 0, false
	}

	diff := absInt64(cur, amount-dryOutAmount)
	return dryOut, drySuccess, diff, true
}

func findNearestFailAmountExactOut(cur realm, inputToken, outputToken string, route, quote, amountLimit string, knownSuccess, knownFail int64) (int64, string, bool, int64, bool) {
	left := knownSuccess + 1
	right := knownFail
	bestAmount := knownFail
	bestDryOut := ""
	bestSuccess := false
	bestDiff := int64(0)
	bestParsed := false

	for left <= right {
		mid := left + (right-left)/2
		dryOut, drySuccess, diff, parsed := drySwapExactOutForAmount(cur, inputToken, outputToken, mid, route, quote, amountLimit)

		if !drySuccess {
			bestAmount = mid
			bestDryOut = dryOut
			bestSuccess = drySuccess
			bestDiff = diff
			bestParsed = parsed
			right = mid - 1
		} else {
			left = mid + 1
		}
	}

	if bestDryOut == "" {
		dryOut, drySuccess, diff, parsed := drySwapExactOutForAmount(cur, inputToken, outputToken, knownFail, route, quote, amountLimit)
		return knownFail, dryOut, drySuccess, diff, parsed
	}

	return bestAmount, bestDryOut, bestSuccess, bestDiff, bestParsed
}

func testMultiHop_TwoHop_ExactIn_Success(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "100000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500"
	quote := "100"

	ufmt.Println("[INFO] Testing Multi-Hop (2-hop) Exact In")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", route, quote, "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 2-hop - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 100000)
		actualIn, actualOut := router.ExactInSwapRoute(
			cross(cur), barPath, fooPath, amount, route, quote, "1",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 2-hop - in=%s out=%s\n", actualIn, actualOut)
		ufmt.Printf("[EXPECTED] Results should match: DryIn=%s ActualIn=%s, DryOut=%s ActualOut=%s\n", dryIn, actualIn, dryOut, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 2-hop exact-in success case unexpectedly failed")
	}
}

func testMultiHop_TwoHop_ExactOut_Success(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "663"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500"
	quote := "100"

	ufmt.Println("[INFO] Testing Multi-Hop (2-hop) Exact Out - Success")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_OUT", route, quote, "999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 2-hop ExactOut success - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 2)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, fooPath, amount, route, quote, "999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 2-hop ExactOut success - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 2-hop success case unexpectedly failed")
	}
}

func testMultiHop_TwoHop_ExactOut_Fail(cur realm) {
	testing.SetRealm(aliceRealm)

	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500"
	amountLimit := "999999999"
	requestedAmount, _, _, _, _ := findNearestFailAmountExactOut(cur,
		barPath, fooPath, route, "100", amountLimit,
		663, 1000000000,
	)
	amount := strconv.FormatInt(requestedAmount, 10)

	ufmt.Println("[INFO] Testing Multi-Hop (2-hop) Exact Out - Fail")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_OUT", route, "100", amountLimit,
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 2-hop ExactOut fail - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 2)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, fooPath, amount, route, "100", amountLimit,
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 2-hop ExactOut fail - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap fail case returned success=false, skipping actual swap")
	}
}

func testMultiHop_TwoRoute_TwoHop_ExactIn(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "100000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500"
	quote := "50,50"

	ufmt.Println("[INFO] Testing Multi-Hop (2-hop, two-route) Exact In")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", route, quote, "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 2-hop two-route ExactIn - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 100000)
		actualIn, actualOut := router.ExactInSwapRoute(
			cross(cur), barPath, fooPath, amount, route, quote, "1",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 2-hop two-route ExactIn - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 2-hop two-route exact-in case failed")
	}
}

func testMultiHop_TwoRoute_TwoHop_ExactOut_Success(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "1000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500"
	quote := "99,1"

	ufmt.Println("[INFO] Testing Multi-Hop (2-hop, two-route) Exact Out - Success")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_OUT", route, quote, "999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 2-hop two-route ExactOut success - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 4)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, fooPath, amount, route, quote, "999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 2-hop two-route ExactOut success - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 2-hop two-route success case unexpectedly failed")
	}
}

func testMultiHop_TwoRoute_TwoHop_ExactOut_Fail(cur realm) {
	testing.SetRealm(aliceRealm)

	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500"
	quote := "50,50"
	amountLimit := "999999999"
	requestedAmount, _, _, _, _ := findNearestFailAmountExactOut(cur,
		barPath, fooPath, route, quote, amountLimit,
		1000, 1000000000,
	)
	amount := strconv.FormatInt(requestedAmount, 10)

	ufmt.Println("[INFO] Testing Multi-Hop (2-hop, two-route) Exact Out - Fail")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_OUT", route, quote, amountLimit,
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 2-hop two-route ExactOut fail - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 4)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, fooPath, amount, route, quote, amountLimit,
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 2-hop two-route ExactOut fail - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 2-hop two-route fail case returned success=false")
	}
}

func testMultiHop_ThreeHop_ExactIn_Success(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500*POOL*gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	ufmt.Println("[INFO] Testing Multi-Hop (3-hop round trip) - swapCount=3")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, fooPath, amount, "EXACT_IN", route, "100", "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 3-hop - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 10000)
		actualIn, actualOut := router.ExactInSwapRoute(
			cross(cur), barPath, fooPath, amount, route, "100", "1",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 3-hop - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 3-hop exact-in success case unexpectedly failed")
	}
}

func testMultiHop_ThreeHop_ExactOut_Success(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "663"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500"

	ufmt.Println("[INFO] Testing Multi-Hop (3-hop) Exact Out - Success")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, quxPath, amount, "EXACT_OUT", route, "100", "999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 3-hop ExactOut success - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 3)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, quxPath, amount, route, "100", "999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 3-hop ExactOut success - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 3-hop success case unexpectedly failed")
	}
}

func testMultiHop_ThreeHop_ExactOut_Fail(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500"

	ufmt.Println("[INFO] Testing Multi-Hop (3-hop) Exact Out - Fail")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, quxPath, amount, "EXACT_OUT", route, "100", "999999999",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 3-hop ExactOut fail - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 3)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, quxPath, amount, route, "100", "999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 3-hop ExactOut fail - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap fail case returned success=false, skipping actual swap")
	}
}

func testMultiHop_TwoRoute_ThreeHop_ExactIn(cur realm) {
	testing.SetRealm(aliceRealm)

	amount := "10000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500"
	quote := "90,10"

	ufmt.Println("[INFO] Testing Multi-Hop (3-hop, two-route) Exact In")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, quxPath, amount, "EXACT_IN", route, quote, "1",
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 3-hop two-route ExactIn - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 10000)
		actualIn, actualOut := router.ExactInSwapRoute(
			cross(cur), barPath, quxPath, amount, route, quote, "1",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 3-hop two-route ExactIn - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 3-hop two-route exact-in case failed")
	}
}

func testMultiHop_TwoRoute_ThreeHop_ExactOut_Success(cur realm) {
	testing.SetRealm(aliceRealm)

	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500"
	quote := "50,50"
	amount := "2"

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, quxPath, amount, "EXACT_OUT", route, quote, "999999999",
		)
	}(cross(cur))

	ufmt.Println("[INFO] Testing Multi-Hop (3-hop, two-route) Exact Out - Success")
	ufmt.Printf("[EXPECTED] DrySwap 3-hop two-route ExactOut success - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 4)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, quxPath, amount, route, quote, "999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 3-hop two-route ExactOut success - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 3-hop two-route success case unexpectedly failed")
	}
}

func testMultiHop_TwoRoute_ThreeHop_ExactOut_Fail(cur realm) {
	testing.SetRealm(aliceRealm)

	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500"
	quote := "90,10"
	amountLimit := "999999999"
	requestedAmount, _, _, _, _ := findNearestFailAmountExactOut(cur,
		barPath, quxPath, route, quote, amountLimit,
		2, 1000000,
	)
	amount := strconv.FormatInt(requestedAmount, 10)

	ufmt.Println("[INFO] Testing Multi-Hop (3-hop, two-route) Exact Out - Fail")

	dryIn, dryOut, drySuccess := func(cur realm) (string, string, bool) {
		return router.DrySwapRoute(
			barPath, quxPath, amount, "EXACT_OUT", route, quote, amountLimit,
		)
	}(cross(cur))
	ufmt.Printf("[EXPECTED] DrySwap 3-hop two-route ExactOut fail - in=%s out=%s success=%t\n", dryIn, dryOut, drySuccess)
	printExactOutTolerance(cur, amount, dryOut, 4)

	if drySuccess {
		common.SafeGRC20Approve(cross(cur), barPath, routerAddr, 999999999)
		actualIn, actualOut := router.ExactOutSwapRoute(
			cross(cur), barPath, quxPath, amount, route, quote, amountLimit,
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[EXPECTED] Actual swap 3-hop two-route ExactOut fail - in=%s out=%s\n", actualIn, actualOut)
	} else {
		ufmt.Println("[INFO] DrySwap 3-hop two-route fail case returned success=false")
	}
}

// Output:
// [SCENARIO] 1. Initialize pool with multiple positions
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Distributing Baz tokens
// [INFO] Distributing Qux tokens
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
// [INFO] Testing zero amount validation
// [EXPECTED] Zero exact in - Correctly aborted with expected message
// [EXPECTED] Zero exact out - Correctly aborted with expected message
//
// [INFO] Testing reverse direction swap consistency
// [EXPECTED] Forward swap - Dry: in=1000000 out(with fee)=931857046 | Actual: in=1000000 out=-931857046
// [EXPECTED] Reverse swap - Dry: in=1000000 out(with fee)=1069 | Actual: in=1000000 out=-1069
//
// [INFO] Testing with maximum slippage protection
// [EXPECTED] Tight slippage - DrySwap returns in=1000000 out=931161307 success=true
// [EXPECTED] Swap - Dry: in=1000000 out(with fee)=931161307 | Actual: in=1000000 out(with fee)=-931161307
//
// [SCENARIO] 6. Test Multi-Hop Routes
// [INFO] 2-hop single-route matrix
// [INFO] Testing Multi-Hop (2-hop) Exact In
// [EXPECTED] DrySwap 2-hop - in=100000 out=271134 success=true
// [EXPECTED] Actual swap 2-hop - in=100000 out=-271134
// [EXPECTED] Results should match: DryIn=100000 ActualIn=100000, DryOut=271134 ActualOut=-271134
//
// [INFO] Testing Multi-Hop (2-hop) Exact Out - Success
// [EXPECTED] DrySwap 2-hop ExactOut success - in=246 out=665 success=true
// [EXPECTED] ExactOut tolerance check: requested=663 dryOut=665 diff=2 tolerance=2 withinTolerance=true
// [EXPECTED] Actual swap 2-hop ExactOut success - in=246 out=-663
//
// [INFO] Testing Multi-Hop (2-hop) Exact Out - Fail
// [EXPECTED] DrySwap 2-hop ExactOut fail - in=738 out=2000 success=false
// [EXPECTED] ExactOut tolerance check: requested=1997 dryOut=2000 diff=3 tolerance=2 withinTolerance=false
// [INFO] DrySwap fail case returned success=false, skipping actual swap
//
// [INFO] 2-hop two-route matrix
// [INFO] Testing Multi-Hop (2-hop, two-route) Exact In
// [EXPECTED] DrySwap 2-hop two-route ExactIn - in=100000 out=271133 success=true
// [EXPECTED] Actual swap 2-hop two-route ExactIn - in=100000 out=-271133
//
// [INFO] Testing Multi-Hop (2-hop, two-route) Exact Out - Success
// [EXPECTED] DrySwap 2-hop two-route ExactOut success - in=372 out=1004 success=true
// [EXPECTED] ExactOut tolerance check: requested=1000 dryOut=1004 diff=4 tolerance=4 withinTolerance=true
// [EXPECTED] Actual swap 2-hop two-route ExactOut success - in=372 out=-1000
//
// [INFO] Testing Multi-Hop (2-hop, two-route) Exact Out - Fail
// [EXPECTED] DrySwap 2-hop two-route ExactOut fail - in=1476 out=3998 success=false
// [EXPECTED] ExactOut tolerance check: requested=3993 dryOut=3998 diff=5 tolerance=4 withinTolerance=false
// [INFO] DrySwap 2-hop two-route fail case returned success=false
//
// [INFO] 3-hop single-route matrix
// [INFO] Testing Multi-Hop (3-hop round trip) - swapCount=3
// [EXPECTED] DrySwap 3-hop - in=10000 out=9297855 success=true
// [EXPECTED] Actual swap 3-hop - in=10000 out=-9298785
//
// [INFO] Testing Multi-Hop (3-hop) Exact Out - Success
// [EXPECTED] DrySwap 3-hop ExactOut success - in=247 out=666 success=true
// [EXPECTED] ExactOut tolerance check: requested=663 dryOut=666 diff=3 tolerance=3 withinTolerance=true
// [EXPECTED] Actual swap 3-hop ExactOut success - in=247 out=-663
//
// [INFO] Testing Multi-Hop (3-hop) Exact Out - Fail
// [EXPECTED] DrySwap 3-hop ExactOut fail - in=7 out=14 success=false
// [EXPECTED] ExactOut tolerance check: requested=10 dryOut=14 diff=4 tolerance=3 withinTolerance=false
// [INFO] DrySwap fail case returned success=false, skipping actual swap
//
// [INFO] 3-hop two-route matrix
// [INFO] Testing Multi-Hop (3-hop, two-route) Exact In
// [EXPECTED] DrySwap 3-hop two-route ExactIn - in=10000 out=25381 success=true
// [EXPECTED] Actual swap 3-hop two-route ExactIn - in=10000 out=-25381
//
// [INFO] Testing Multi-Hop (3-hop, two-route) Exact Out - Success
// [EXPECTED] DrySwap 3-hop two-route ExactOut success - in=6 out=6 success=true
// [EXPECTED] ExactOut tolerance check: requested=2 dryOut=6 diff=4 tolerance=4 withinTolerance=true
// [EXPECTED] Actual swap 3-hop two-route ExactOut success - in=6 out=-2
//
// [INFO] Testing Multi-Hop (3-hop, two-route) Exact Out - Fail
// [EXPECTED] DrySwap 3-hop two-route ExactOut fail - in=962 out=2221 success=false
// [EXPECTED] ExactOut tolerance check: requested=2216 dryOut=2221 diff=5 tolerance=4 withinTolerance=false
// [INFO] DrySwap 3-hop two-route fail case returned success=false
