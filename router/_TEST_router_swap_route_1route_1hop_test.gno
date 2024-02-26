package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/r/demo/consts"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(test1)
	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.CreatePool(barPath, bazPath, uint16(500), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	jsonOutput := pl.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response").Array()), 1)
}

func TestPositionMint(t *testing.T) {
	// bar_baz_500 by test1
	std.TestSetOrigCaller(test1)

	// Mint
	pn.Mint(barPath, bazPath, uint16(500), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, max_timeout)
}

func TestDrySwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		barPath,      // inputToken
		bazPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(2707))
}

func TestSwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetPrevAddr(test1)
	baz.Approve(a2u(consts.ROUTER_ADDR), uint64(consts.MAX_UINT64))

	swapResult := SwapRoute(
		barPath,      // inputToken
		bazPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
		2700,  // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(2707))
}

func TestDrySwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		barPath,      // inputToken
		bazPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(369))
}

func TestSwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetPrevAddr(test1)
	baz.Approve(a2u(consts.ROUTER_ADDR), uint64(consts.MAX_UINT64))

	swapResult := SwapRoute(
		barPath,      // inputToken
		bazPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500", // strRouteArr
		"100", // quoteArr
		370,   // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(369))
}

func TestDrySwapRouteBazBarExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		bazPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(368))
}

func TestSwapRouteBazBarExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	swapResult := SwapRoute(
		bazPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
		360,   // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(368))
}

func TestDrySwapRouteBazBarExactOut(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		bazPath,      // inputToken
		barPath,      // outputToken
		bigint(3000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(1103))
}

func TestSwapRouteBazBarExactOut(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.ROUTER_ADDR), uint64(consts.MAX_UINT64))

	swapResult := SwapRoute(
		bazPath,      // inputToken
		barPath,      // outputToken
		bigint(3000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"100", // quoteArr
		1100,  // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(1103))
}
