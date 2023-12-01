package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	pl "gno.land/r/pool"
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
	barPath = "gno.land/r/bar"
	bazPath = "gno.land/r/baz"

	MAX_TIMEOUT bigint = 9999999999
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)
	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	pl.CreatePool(barPath, bazPath, uint16(500), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	jsonOutput := pl.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 1)
}

func TestPositionMint(t *testing.T) {
	// bar_baz_500 by lp01
	std.TestSetOrigCaller(lp01)

	// Mint
	pos.Mint(barPath, bazPath, uint16(500), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, MAX_TIMEOUT)
}

func TestDrySwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	dryResult := DrySwapRoute(
		barPath,                             // inputToken
		bazPath,                             // outputToken
		bigint(1000),                        // amountSpecified
		"EXACT_IN",                          // swapType
		"gno.land/r/bar:gno.land/r/baz:500", // strRouteArr
		"100",                               // quoteArr
	)

	shouldEQ(t, dryResult, bigint(2711))
}

func TestDrySwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	dryResult := DrySwapRoute(
		barPath,                             // inputToken
		bazPath,                             // outputToken
		bigint(1000),                        // amountSpecified
		"EXACT_OUT",                         // swapType
		"gno.land/r/bar:gno.land/r/baz:500", // strRouteArr
		"100",                               // quoteArr
	)

	shouldEQ(t, dryResult, bigint(368))
}

func TestDrySwapRouteBazBarExactIn(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	dryResult := DrySwapRoute(
		bazPath,                             // inputToken
		barPath,                             // outputToken
		bigint(1000),                        // amountSpecified
		"EXACT_IN",                          // swapType
		"gno.land/r/baz:gno.land/r/bar:500", // strRouteArr
		"100",                               // quoteArr
	)

	shouldEQ(t, dryResult, bigint(367))
}

func TestDrySwapRouteBazBarExactOut(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	dryResult := DrySwapRoute(
		bazPath,                             // inputToken
		barPath,                             // outputToken
		bigint(3000),                        // amountSpecified
		"EXACT_IN",                          // swapType
		"gno.land/r/baz:gno.land/r/bar:500", // strRouteArr
		"100",                               // quoteArr
	)

	shouldEQ(t, dryResult, bigint(1101))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
