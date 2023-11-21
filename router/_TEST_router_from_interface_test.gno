package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"
	pos "gno.land/r/position"

	"gno.land/r/bar"
	"gno.land/r/qux"
)

var (
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	tr01 = testutils.TestAddress("tr01") // Trader 01

	poolAddr   = std.DerivePkgAddr("gno.land/r/pool")
	posAddr    = std.DerivePkgAddr("gno.land/r/position")
	routerAddr = std.DerivePkgAddr("gno.land/r/router")
)

var (
	// Common
	barPath     = "gno.land/r/bar"
	bazPath     = "gno.land/r/baz"
	quxPath     = "gno.land/r/qux"
	test_fee100 = uint16(100)

	max_timeout = bigint(9999999999)
)

// func init() {
// 	println(pc01, "// pc01")
// 	println(lp01, "// lp01")
// 	println(tr01, "// tr01")
// 	println(poolAddr, "// poolAddr")
// 	println(posAddr, "// posAddr")
// 	println(routerAddr, "// routerAddr")
// }

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)
	p.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	p.CreatePool(barPath, bazPath, test_fee100, 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	p.CreatePool(bazPath, quxPath, test_fee100, 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253 // 7.29

	p.CreatePool(barPath, quxPath, test_fee100, 194861066650599577346362855175) // tick = 18_000, ratio = 6.049103056933383

	// findSwapPaths("gno.land/r/bar", "gno.land/r/qux")                           // 2 paths
	// 1) bar:baz:100*POOL*baz:qux:100
	// 2) bar:qux:100

	jsonOutput := p.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 3)
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	pos.Mint(barPath, bazPath, test_fee100, int32(9000), int32(11000), bigint(100000000), bigint(100000000), 0, 0, max_timeout)
	pos.Mint(bazPath, quxPath, test_fee100, int32(9000), int32(11000), bigint(100000000), bigint(100000000), 0, 0, max_timeout)

	pos.Mint(barPath, quxPath, test_fee100, int32(16000), int32(20000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
}

func TestEstimateRouteQuotesExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)
	exactInQuotesJsonStr := EstimateRouteQuotes(
		barPath,          // inputToken
		quxPath,          // outputToken
		bigint(10000000), // amountSpecified
		"EXACT_IN",       // swapType
		"gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/qux:100", // strPool
		5, // divideBy
	)
	shouldEQ(t, gjson.Get(exactInQuotesJsonStr, "0.Pools").String(), "gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100")
	shouldEQ(t, gjson.Get(exactInQuotesJsonStr, "0.Quote").Int(), 5)
	shouldEQ(t, gjson.Get(exactInQuotesJsonStr, "0.InputAmount").Int(), 500000)
	shouldEQ(t, gjson.Get(exactInQuotesJsonStr, "0.OutputAmount").Int(), 3684341)
}

func TestEstimateRouteQuotesExactOut(t *testing.T) {
	std.TestSetOrigCaller(tr01)
	exactOutQuotesJsonStr := EstimateRouteQuotes(
		barPath,        // inputToken
		quxPath,        // outputToken
		bigint(888888), // amountSpecified
		"EXACT_OUT",    // swapType
		"gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/qux:100", // strPool
		10, // divideBy
	)
	shouldEQ(t, gjson.Get(exactOutQuotesJsonStr, "0.Pools").String(), "gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100")
	shouldEQ(t, gjson.Get(exactOutQuotesJsonStr, "0.Quote").Int(), 10)
	shouldEQ(t, gjson.Get(exactOutQuotesJsonStr, "0.InputAmount").Int(), -88880)
	shouldEQ(t, gjson.Get(exactOutQuotesJsonStr, "0.OutputAmount").Int(), 12032)
}

func TestDrySwapRouteExactIn(t *testing.T) {
	std.TestSetOrigCaller(tr01)
	resultAmount := DrySwapRoute(
		barPath,          // inputToken
		quxPath,          // outputToken
		bigint(10000000), // amountSpecified
		"EXACT_IN",       // swapType
		"gno.land/r/bar:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100", // strRouteArr
		"10,90", // quotes
	)
	shouldEQ(t, resultAmount, bigint(69377564))
}

func TestDrySwapRouteExactOut(t *testing.T) {
	std.TestSetOrigCaller(tr01)
	resultAmount := DrySwapRoute(
		barPath,        // inputToken
		quxPath,        // outputToken
		bigint(888888), // amountSpecified
		"EXACT_OUT",    // swapType
		"gno.land/r/bar:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100", // strRouteArr
		"70,30", // quotes
	)
	shouldEQ(t, resultAmount, bigint(139576))
}

func TestSwapRouteExactIn(t *testing.T) {
	tr01OldBar := bar.BalanceOf(a2u(tr01))
	tr01OldQux := qux.BalanceOf(a2u(tr01))
	poolOldBar := bar.BalanceOf(a2u(poolAddr))
	poolOldQux := qux.BalanceOf(a2u(poolAddr))
	routerOldBar := bar.BalanceOf(a2u(routerAddr))
	routerOldQux := qux.BalanceOf(a2u(routerAddr))

	shouldEQ(t, tr01OldBar, bigint(50000000000))
	shouldEQ(t, tr01OldQux, bigint(50000000000))
	shouldEQ(t, routerOldBar, bigint(0))
	shouldEQ(t, routerOldQux, bigint(0))

	std.TestSetOrigCaller(tr01)
	recv := SwapRoute(
		barPath,          // inputToken
		quxPath,          // outputToken
		bigint(10000000), // amountSpecified
		"EXACT_IN",       // swapType
		"gno.land/r/bar:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100", // strRouteArr
		"10,90", // quotes
		123_456, // tokenAmountLimit
	)

	tr01NewBar := bar.BalanceOf(a2u(tr01))
	tr01NewQux := qux.BalanceOf(a2u(tr01))
	poolNewBar := bar.BalanceOf(a2u(poolAddr))
	poolNewQux := qux.BalanceOf(a2u(poolAddr))
	routerNewBar := bar.BalanceOf(a2u(routerAddr))
	routerNewQux := qux.BalanceOf(a2u(routerAddr))

	shouldEQ(t, routerOldBar, bigint(0))
	shouldEQ(t, routerOldQux, bigint(0))
	shouldEQ(t, tr01OldBar-tr01NewBar, uint64(10000000))
	shouldEQ(t, tr01NewQux-tr01OldQux, uint64(recv))
	shouldEQ(t, poolNewBar-poolOldBar, uint64(10000000))
	shouldEQ(t, poolOldQux-poolNewQux, uint64(recv))
}

func TestSwapRouteExactOut(t *testing.T) {
	tr01OldBar := bar.BalanceOf(a2u(tr01))
	tr01OldQux := qux.BalanceOf(a2u(tr01))
	poolOldBar := bar.BalanceOf(a2u(poolAddr))
	poolOldQux := qux.BalanceOf(a2u(poolAddr))
	routerOldBar := bar.BalanceOf(a2u(routerAddr))
	routerOldQux := qux.BalanceOf(a2u(routerAddr))

	shouldEQ(t, tr01OldBar, bigint(49990000000))
	shouldEQ(t, tr01OldQux, bigint(50069377564))
	shouldEQ(t, routerOldBar, bigint(0))
	shouldEQ(t, routerOldQux, bigint(0))

	std.TestSetOrigCaller(tr01)
	sent := SwapRoute(
		barPath,        // inputToken
		quxPath,        // outputToken
		bigint(888888), // amountSpecified
		"EXACT_OUT",    // swapType
		"gno.land/r/bar:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100", // strRouteArr
		"70,30", // quotes
		300000,  // tokenAmountLimit
	)

	tr01NewBar := bar.BalanceOf(a2u(tr01))
	tr01NewQux := qux.BalanceOf(a2u(tr01))
	poolNewBar := bar.BalanceOf(a2u(poolAddr))
	poolNewQux := qux.BalanceOf(a2u(poolAddr))
	routerNewBar := bar.BalanceOf(a2u(routerAddr))
	routerNewQux := qux.BalanceOf(a2u(routerAddr))

	shouldEQ(t, routerOldBar, bigint(0))
	shouldEQ(t, routerOldQux, bigint(0))
	shouldEQ(t, tr01OldBar-tr01NewBar, uint64(sent))
	shouldEQ(t, tr01NewQux-tr01OldQux, uint64(888800))
	shouldEQ(t, poolNewBar-poolOldBar, uint64(sent))
	shouldEQ(t, poolOldQux-poolNewQux, uint64(888800))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
