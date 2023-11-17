package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"
	pos "gno.land/r/position"
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
	fooPath = "gno.land/r/foo" // token1
	barPath = "gno.land/r/bar" // token2
	bazPath = "gno.land/r/baz" // token3
	quxPath = "gno.land/r/qux" // token4

	test_fee100 = uint16(100)
	test_fee500 = uint16(500)

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

	pos.Mint(barPath, quxPath, test_fee100, int32(16000), int32(20000), bigint(100000), bigint(100000), 0, 0, max_timeout)
}

func TestEstimateRouteQuotesExactIn(t *testing.T) {
	zz := EstimateRouteQuotes(
		barPath,          // inputToken
		quxPath,          // outputToken
		bigint(10000000), // amountSpecified
		"EXACT_IN",       // swapType
		"gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/qux:100", // strPool
		5, // divideBy
	)
	// println(zz)
}

func TestEstimateRouteQuotesExactOut(t *testing.T) {
	zz := EstimateRouteQuotes(
		barPath,        // inputToken
		quxPath,        // outputToken
		bigint(888888), // amountSpecified
		"EXACT_OUT",    // swapType
		"gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100,gno.land/r/bar:gno.land/r/qux:100", // strPool
		10, // divideBy
	)
	println(zz)
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldGTE(t *testing.T, l, r interface{}) {
	if !(l >= r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLTE(t *testing.T, l, r interface{}) {
	if !(l <= r) {
		t.Errorf("expected %v < %v", l, r)
	}
}
