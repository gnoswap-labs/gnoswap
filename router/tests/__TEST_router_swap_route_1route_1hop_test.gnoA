package router

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"
	pn "gno.land/r/gnoswap/v2/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	"gno.land/r/gnoswap/v2/gns"
)

func TestCreatePool(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	gns.Approve(a2u(consts.POOL_ADDR), pl.GetPoolCreationFee())
	pl.CreatePool(barPath, bazPath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/pool CreatePool [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500}]}

	// jsonOutput := pl.ApiGetPools()
	// jsonStr := gjson.Parse(jsonOutput)
	// shouldEQ(t, len(jsonStr.Get("response").Array()), 1)
}

func TestPositionMint(t *testing.T) {
	// bar_baz_500 by gsa
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.POOL_ADDR), 36790)
	baz.Approve(a2u(consts.POOL_ADDR), 100000)

	// Mint
	tokenId, liquidity, amount0, amount1 := pn.Mint(barPath, bazPath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, gsa.String())
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/position Mint [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_poolPath gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_tickLower 9000} {p_tickUpper 11000} {tokenId 1} {liquidity 1243732} {amount0 36790} {amount1 100000}]}

	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, amount0, "36790")
	shouldEQ(t, amount1, "100000")
}

func TestDrySwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	dryResult := DrySwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, "2711")
}

func TestSwapRouteBarBazExactIn(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	bar.Approve(a2u(consts.POOL_ADDR), uint64(1000))
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	amountIn, amountOut := SwapRoute(
		barPath,    // inputToken
		bazPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", // strRouteArr
		"100",  // quoteArr
		"2700", // tokenAmountLimit
	)
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/pool Swap [{m_callType INDIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm gno.land/r/gnoswap/v2/router} {p_poolPath gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_zeroForOne true} {p_amountSpecified 1000} {p_sqrtPriceLimitX96 4295128740} {p_payer g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {p_recipient g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {amount0 1000} {amount1 -2711} {protocol_fee0 0} {protocol_fee1 0} {swap_fee 1}]}
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/router SwapRoute [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_input gno.land/r/onbloc/bar} {p_output gno.land/r/onbloc/baz} {p_swapType EXACT_IN} {p_amountSpecified 1000} {p_route gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_quote 100} {amountIn 1000} {amountOut -2707}]}

	shouldEQ(t, amountIn, "1000")
	shouldEQ(t, amountOut, "-2707")
}

func TestDrySwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	dryResult := DrySwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, "371")
}

func TestSwapRouteBarBazExactOut(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	bar.Approve(a2u(consts.POOL_ADDR), uint64(1000))
	baz.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	amountIn, amountOut := SwapRoute(
		barPath,     // inputToken
		bazPath,     // outputToken
		"1000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", // strRouteArr
		"100", // quoteArr
		"371", // tokenAmountLimit
	)
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/pool Swap [{m_callType INDIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm gno.land/r/gnoswap/v2/router} {p_poolPath gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_zeroForOne true} {p_amountSpecified -1000} {p_sqrtPriceLimitX96 4295128740} {p_payer g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {p_recipient g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {amount0 371} {amount1 -1000} {protocol_fee0 0} {protocol_fee1 0} {swap_fee 1} ]}
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/router SwapRoute [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_input gno.land/r/onbloc/bar} {p_output gno.land/r/onbloc/baz} {p_swapType EXACT_OUT} {p_amountSpecified 1000} {p_route gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_quote 100} {amountIn 371} {amountOut -999}]}

	shouldEQ(t, amountIn, "371")
	shouldEQ(t, amountOut, "-999")
}

func TestDrySwapRouteBazBarExactIn(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	dryResult := DrySwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, "368")
}

func TestSwapRouteBazBarExactIn(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	baz.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX) // ITS FOR 0.15% fee

	amountIn, amountOut := SwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100", // quoteArr
		"360", // tokenAmountLimit
	)
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/pool Swap [{m_callType INDIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm gno.land/r/gnoswap/v2/router} {p_poolPath gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_zeroForOne false} {p_amountSpecified 1000} {p_sqrtPriceLimitX96 1461446703485210103287273052203988822378723970341} {p_payer g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {p_recipient g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {amount0 -368} {amount1 1000} {protocol_fee0 0} {protocol_fee1 0} {swap_fee 1}]}
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/router SwapRoute [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_input gno.land/r/onbloc/baz} {p_output gno.land/r/onbloc/bar} {p_swapType EXACT_IN} {p_amountSpecified 1000} {p_route gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500} {p_quote 100} {amountIn 1000} {amountOut -368}]}

	shouldEQ(t, amountIn, "1000")
	shouldEQ(t, amountOut, "-368")
}

func TestDrySwapRouteBazBarExactOut(t *testing.T) {
	std.TestSetRealm(gsaRealm)

	dryResult := DrySwapRoute(
		bazPath,     // inputToken
		barPath,     // outputToken
		"3000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100", // quoteArr
	)

	shouldEQ(t, dryResult, "8171")
}

func TestSwapRouteBazBarExactOut(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	bar.Approve(a2u(consts.ROUTER_ADDR), consts.UINT64_MAX)

	amountIn, amountOut := SwapRoute(
		bazPath,     // inputToken
		barPath,     // outputToken
		"3000",      // amountSpecified
		"EXACT_OUT", // swapType
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100",  // quoteArr
		"8200", // tokenAmountLimit
	)
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/pool Swap [{m_callType INDIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm gno.land/r/gnoswap/v2/router} {p_poolPath gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500} {p_zeroForOne false} {p_amountSpecified -3000} {p_sqrtPriceLimitX96 1461446703485210103287273052203988822378723970341} {p_payer g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {p_recipient g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {amount0 -3000} {amount1 8171} {protocol_fee0 0} {protocol_fee1 0} {swap_fee 5}]}
	// ---       event: {GNOSWAP gno.land/r/gnoswap/v2/router SwapRoute [{m_callType DIRECT} {m_origCaller g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c} {m_prevRealm } {p_input gno.land/r/onbloc/baz} {p_output gno.land/r/onbloc/bar} {p_swapType EXACT_OUT} {p_amountSpecified 3000} {p_route gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500} {p_quote 100} {amountIn 8171} {amountOut -2996}]}

	shouldEQ(t, amountIn, "8171")
	shouldEQ(t, amountOut, "-2996")
}
