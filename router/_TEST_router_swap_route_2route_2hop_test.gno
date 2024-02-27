package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/qux"
)

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	pl.InitManual()
}

func TestCreatePool(t *testing.T) {
	std.TestSetPrevAddr(test1)
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE*2)

	pl.CreatePool(barPath, bazPath, uint16(500), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	pl.CreatePool(bazPath, quxPath, uint16(500), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	jsonOutput := pl.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response").Array()), 2)
}

func TestPositionMint(t *testing.T) {
	// bar_baz_500 by test1
	std.TestSetPrevAddr(test1)

	bar.Approve(a2u(consts.POOL_ADDR), uint64(consts.MAX_UINT64))
	baz.Approve(a2u(consts.POOL_ADDR), uint64(consts.MAX_UINT64))
	qux.Approve(a2u(consts.POOL_ADDR), uint64(consts.MAX_UINT64))

	// Mint
	pn.Mint(barPath, bazPath, uint16(500), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, max_timeout)
	pn.Mint(bazPath, quxPath, uint16(500), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, max_timeout)
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
	std.TestSetPrevAddr(test1)

	bar.Approve(a2u(consts.POOL_ADDR), 10000)
	qux.Approve(a2u(consts.ROUTER_ADDR), 10000)

	swapResult := SwapRoute(
		barPath,      // inputToken
		quxPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500,gno.land/r/demo/bar:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:500", // strRouteArr
		"50,50", // quoteArr
		1,       // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(7318))
}

func TestDrySwapRouteBarQuxExactOut(t *testing.T) {
	std.TestSetPrevAddr(test1)

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
	std.TestSetPrevAddr(test1)

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
	std.TestSetPrevAddr(test1)

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
	std.TestSetPrevAddr(test1)

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
	std.TestSetPrevAddr(test1)

	dryResult := DrySwapRoute(
		quxPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500,gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"30,70", // quoteArr
	)

	shouldEQ(t, dryResult, bigint(7285))
}

func TestwapRouteQuxBarExactOut(t *testing.T) {
	std.TestSetPrevAddr(test1)

	qux.Approve(a2u(consts.POOL_ADDR), 10000)
	bar.Approve(a2u(consts.ROUTER_ADDR), 10000)

	swapResult := SwapRoute(
		quxPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_OUT",  // swapType
		"gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500,gno.land/r/demo/qux:gno.land/r/demo/baz:500*POOL*gno.land/r/demo/baz:gno.land/r/demo/bar:500", // strRouteArr
		"30,70", // quoteArr
		99999,   // tokenAmountLimit
	)

	shouldEQ(t, swapResult, bigint(7278))
}
