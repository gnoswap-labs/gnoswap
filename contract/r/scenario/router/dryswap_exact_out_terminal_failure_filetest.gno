// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strings"
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

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
	_ "gno.land/r/onbloc/qux"
)

const (
	maxApproval int64 = 9223372036854775807
	poolFee           = uint32(500)
)

var (
	t *testing.T

	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	quxPath = "gno.land/r/onbloc/qux.QUX"
)

func main(cur realm) {
	setupTerminalFailurePools(cur)

	ufmt.Println("[SCENARIO] Multi-hop ExactOut terminal-liquidity failures")

	assertExactOutFailure(cur, "2-hop first-hop", 1, quxPath, barPath,
		"gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:500")
	println()
	assertExactOutFailure(cur, "2-hop final-hop", 2, barPath, quxPath,
		"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:500")
	println()

	assertExactOutFailure(cur, "3-hop first-hop", 1, quxPath, barPath,
		"gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/foo.FOO:500*POOL*gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500")
	println()
	assertExactOutFailure(cur, "3-hop middle-hop", 2, barPath, fooPath,
		"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:500*POOL*gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/foo.FOO:500")
	println()
	assertExactOutFailure(cur, "3-hop final-hop", 3, barPath, quxPath,
		"gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500*POOL*gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:500")
}

func setupTerminalFailurePools(cur realm) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)

	for _, token := range []string{barPath, bazPath, fooPath, quxPath} {
		common.SafeGRC20Transfer(0, cur, token, aliceAddr, 1_000_000)
		common.SafeGRC20Approve(0, cur, token, poolAddr, maxApproval)
	}

	createPool(cur, barPath, bazPath)
	createPool(cur, bazPath, fooPath)
	createPool(cur, barPath, fooPath)
	createPool(cur, barPath, quxPath)
	createPool(cur, bazPath, quxPath)

	testing.SetRealm(aliceRealm)
	for _, token := range []string{barPath, bazPath, fooPath, quxPath} {
		common.SafeGRC20Approve(0, cur, token, poolAddr, maxApproval)
	}

	// These ranges are active at the initial price and make every non-BAZ/QUX
	// hop executable.
	mintRange(cur, barPath, bazPath, -1_000, 1_000, "100000", "100000")
	mintRange(cur, bazPath, fooPath, -1_000, 1_000, "100000", "100000")
	mintRange(cur, barPath, fooPath, -1_000, 1_000, "100000", "100000")
	mintRange(cur, barPath, quxPath, -1_000, 1_000, "100000", "100000")

	// This range is reachable only when swapping QUX -> BAZ. A request for
	// 1,000 output tokens exhausts it; BAZ -> QUX has no reachable liquidity.
	mintRange(cur, bazPath, quxPath, 100, 200, "100", "100")
}

func createPool(cur realm, tokenA, tokenB string) {
	testing.SetRealm(adminRealm)
	pl.CreatePool(cross(cur), tokenA, tokenB, poolFee, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
}

func mintRange(cur realm, tokenA, tokenB string, tickLower, tickUpper int32, amountA, amountB string) {
	testing.SetRealm(aliceRealm)
	pn.Mint(cross(cur), tokenA, tokenB, poolFee, tickLower, tickUpper, amountA, amountB, "0", "0", time.Now().Unix()+3600, aliceAddr, "")
}

func assertExactOutFailure(cur realm, name string, failureHop int, inputToken, outputToken, route string) {
	testing.SetRealm(aliceRealm)
	ufmt.Printf("[SCENARIO] %s\n", name)
	ufmt.Printf("[INFO] Route: %s\n", route)
	ufmt.Printf("[INFO] Expected terminal failure at hop %d\n", failureHop)
	ufmt.Println("[INFO] Requested output: 1000")

	dryIn, dryOut, dryErr := func(cur realm) (string, string, error) {
		return router.DrySwapRoute(inputToken, outputToken, "1000", "EXACT_OUT", route, "100", "999999999")
	}(cross(cur))
	uassert.Error(t, dryErr)
	ufmt.Printf("[EXPECTED] DrySwapRoute rejected: in=%s out=%s err=%s\n", dryIn, dryOut, dryErr.Error())

	common.SafeGRC20Approve(0, cur, inputToken, routerAddr, maxApproval)
	actualErr := revive(func() {
		router.ExactOutSwapRoute(
			cross(cur), inputToken, outputToken, "1000", route, "100", "999999999",
			time.Now().Add(time.Hour).Unix(), "",
		)
	})
	if actualErr == nil {
		panic("expected ExactOutSwapRoute to abort")
	}
	actualErrText := ufmt.Sprintf("%v", actualErr)
	if !strings.Contains(actualErrText, dryErr.Error()) {
		panic(ufmt.Sprintf("dry error %q does not match actual error %q", dryErr.Error(), actualErrText))
	}
	ufmt.Printf("[EXPECTED] ExactOutSwapRoute aborted: %s\n", actualErrText)
	ufmt.Println("[RESULT] Dry quote and execution reject the same terminal-limited route")
}

// Output:
// [SCENARIO] Multi-hop ExactOut terminal-liquidity failures
// [SCENARIO] 2-hop first-hop
// [INFO] Route: gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:500
// [INFO] Expected terminal failure at hop 1
// [INFO] Requested output: 1000
// [EXPECTED] DrySwapRoute rejected: in=103 out=97 err=received more than requested in requested=1000, actual=97
// [EXPECTED] ExactOutSwapRoute aborted: [GNOSWAP-ROUTER-001] slippage check failed || received more than requested in requested=1000, actual=97
// [RESULT] Dry quote and execution reject the same terminal-limited route
//
// [SCENARIO] 2-hop final-hop
// [INFO] Route: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:500
// [INFO] Expected terminal failure at hop 2
// [INFO] Requested output: 1000
// [EXPECTED] DrySwapRoute rejected: in=105 out=101 err=received more than requested in requested=1000, actual=101
// [EXPECTED] ExactOutSwapRoute aborted: [GNOSWAP-ROUTER-001] slippage check failed || received more than requested in requested=1000, actual=101
// [RESULT] Dry quote and execution reject the same terminal-limited route
//
// [SCENARIO] 3-hop first-hop
// [INFO] Route: gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/foo.FOO:500*POOL*gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/bar.BAR:500
// [INFO] Expected terminal failure at hop 1
// [INFO] Requested output: 1000
// [EXPECTED] DrySwapRoute rejected: in=103 out=95 err=received more than requested in requested=1000, actual=95
// [EXPECTED] ExactOutSwapRoute aborted: [GNOSWAP-ROUTER-001] slippage check failed || received more than requested in requested=1000, actual=95
// [RESULT] Dry quote and execution reject the same terminal-limited route
//
// [SCENARIO] 3-hop middle-hop
// [INFO] Route: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:500*POOL*gno.land/r/onbloc/qux.QUX:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/foo.FOO:500
// [INFO] Expected terminal failure at hop 2
// [INFO] Requested output: 1000
// [EXPECTED] DrySwapRoute rejected: in=0 out=0 err=[GNOSWAP-POOL-015] swap price out of range || sqrtPriceLimitX96(1461227513878616457037757440299078829107947336293) > slot0Start.sqrtPriceX96(1461227513878616457037757440299078829107947336293) && sqrtPriceLimitX96(1461227513878616457037757440299078829107947336293) < MAX_SQRT_RATIO(1461446703485210103287273052203988822378723970342)
// [EXPECTED] ExactOutSwapRoute aborted: [GNOSWAP-POOL-015] swap price out of range || sqrtPriceLimitX96(1461227513878616457037757440299078829107947336293) > slot0Start.sqrtPriceX96(1461227513878616457037757440299078829107947336293) && sqrtPriceLimitX96(1461227513878616457037757440299078829107947336293) < MAX_SQRT_RATIO(1461446703485210103287273052203988822378723970342)
// [RESULT] Dry quote and execution reject the same terminal-limited route
//
// [SCENARIO] 3-hop final-hop
// [INFO] Route: gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/foo.FOO:500*POOL*gno.land/r/onbloc/foo.FOO:gno.land/r/onbloc/baz.BAZ:500*POOL*gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/qux.QUX:500
// [INFO] Expected terminal failure at hop 3
// [INFO] Requested output: 1000
// [EXPECTED] DrySwapRoute rejected: in=106 out=101 err=received more than requested in requested=1000, actual=101
// [EXPECTED] ExactOutSwapRoute aborted: [GNOSWAP-ROUTER-001] slippage check failed || received more than requested in requested=1000, actual=101
// [RESULT] Dry quote and execution reject the same terminal-limited route
