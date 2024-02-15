package router

import (
	"encoding/gjson"
	"std"
	"testing"

	pl "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(test1)
	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pl.CreatePool(barPath, bazPath, uint16(500), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	pl.CreatePool(bazPath, quxPath, uint16(500), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	jsonOutput := pl.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response").Array()), 2)
}

func TestPositionMint(t *testing.T) {
	// bar_baz_500 by test1
	std.TestSetOrigCaller(test1)

	// Mint
	pos.Mint(barPath, bazPath, uint16(500), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, max_timeout)
	pos.Mint(bazPath, quxPath, uint16(500), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, max_timeout)
}

func TestDrySwapRouteBarQuxExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		barPath,      // inputToken
		quxPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500,gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500", // strRouteArr
		"50,50", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(7346))
}

func TestSwapRouteBarQuxExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	swapResult := SwapRoute(
		barPath,      // inputToken
		quxPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500,gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500", // strRouteArr
		"50,50", // quoteArr
		1,       // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(7328))
}

func TestDrySwapRouteBarQuxExactOut(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		barPath,      // inputToken
		quxPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500,gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500", // strRouteArr
		"50,50", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(136))
}

func TestSwapRouteBarQuxExactOut(t *testing.T) {
	std.TestSetOrigCaller(test1)

	swapResult := SwapRoute(
		barPath,      // inputToken
		quxPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500,gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500", // strRouteArr
		"50,50", // quoteArr
		99999,   // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(136))
}

func TestDrySwapRouteQuxBarExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		quxPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500,gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"30,70", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(135))
}

func TestSwapRouteQuxBarExactIn(t *testing.T) {
	std.TestSetOrigCaller(test1)

	swapResult := SwapRoute(
		quxPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500,gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"30,70", // quoteArr
		1,       // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(135))
}

func TestDrySwapRouteQuxBarExactOut(t *testing.T) {
	std.TestSetOrigCaller(test1)

	dryResult := DrySwapRoute(
		quxPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500,gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"30,70", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(7292))
}

func TestwapRouteQuxBarExactOut(t *testing.T) {
	std.TestSetOrigCaller(test1)

	swapResult := SwapRoute(
		quxPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500,gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"30,70", // quoteArr
		99999,   // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(7286))
}
