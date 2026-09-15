package router

import (
	"chain"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/router"
)

const maxSwapFeeBPS uint64 = 1000

func (r *routerV1) Render(path string) string {
	var action string
	switch path {
	case "":
		action = "### Exact-input single-route swap\n\n" +
			"<gno-form exec=\"ExactInSingleSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Registered input token path\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Registered output token path\" required=\"true\" />\n" +
			"  <gno-input name=\"amountIn\" type=\"text\" placeholder=\"Exact input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Single route: inputToken:outputToken:fee\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOutMin\" type=\"text\" placeholder=\"Minimum output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"sqrtPriceLimitX96\" type=\"text\" placeholder=\"Decimal price limit, or 0\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Unix deadline (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	case "swap/exact-in":
		action = "### Exact-input multi-route swap\n\n" +
			"<gno-form exec=\"ExactInSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Registered input token path\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Registered output token path\" required=\"true\" />\n" +
			"  <gno-input name=\"amountIn\" type=\"text\" placeholder=\"Exact input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Route paths, comma-separated for multiple routes\" required=\"true\" />\n" +
			"  <gno-input name=\"quoteArr\" type=\"text\" placeholder=\"Route percentages, for example 100\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOutMin\" type=\"text\" placeholder=\"Minimum output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Unix deadline (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	case "swap/exact-out":
		action = "### Exact-output multi-route swap\n\n" +
			"<gno-form exec=\"ExactOutSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Registered input token path\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Registered output token path\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOut\" type=\"text\" placeholder=\"Exact output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Route paths, comma-separated for multiple routes\" required=\"true\" />\n" +
			"  <gno-input name=\"quoteArr\" type=\"text\" placeholder=\"Route percentages, for example 100\" required=\"true\" />\n" +
			"  <gno-input name=\"amountInMax\" type=\"text\" placeholder=\"Maximum input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Unix deadline (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	case "swap/exact-out-single":
		action = "### Exact-output single-route swap\n\n" +
			"<gno-form exec=\"ExactOutSingleSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Registered input token path\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Registered output token path\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOut\" type=\"text\" placeholder=\"Exact output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Single route: inputToken:outputToken:fee\" required=\"true\" />\n" +
			"  <gno-input name=\"amountInMax\" type=\"text\" placeholder=\"Maximum input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"sqrtPriceLimitX96\" type=\"text\" placeholder=\"Decimal price limit, or 0\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Unix deadline (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	default:
		return "404\n"
	}

	swapFee := r.GetSwapFee()
	implementation := router.GetImplementationPackagePath()

	return ufmt.Sprintf(
		"# Gnoswap Router\n\n"+
			"## Router status\n\n"+
			"| Field | Value |\n"+
			"| --- | --- |\n"+
			"| Router package | [gno.land/r/gnoswap/router](/r/gnoswap/router) |\n"+
			"| Realm address | `%s` |\n"+
			"| Active implementation | [%s](%s) |\n"+
			"| Router halted | %t |\n\n"+
			"## Swap fee configuration\n\n"+
			"| Field | Value |\n"+
			"| --- | --- |\n"+
			"| Swap fee | %d bps |\n"+
			"| Maximum swap fee | %d bps (10%%) |\n"+
			"| Fee unit | 1 bps = 0.01%% of the output-token amount |\n"+
			"| Amount unit | Integer token base units; decimals are token-specific |\n\n"+
			"## User swap actions\n\n"+
			"[Exact input: single route](/r/gnoswap/router) · "+
			"[Exact input: multiple routes](/r/gnoswap/router:swap/exact-in) · "+
			"[Exact output: single route](/r/gnoswap/router:swap/exact-out-single) · "+
			"[Exact output: multiple routes](/r/gnoswap/router:swap/exact-out)\n\n"+
			"These forms prepare a Gnoweb command preview only; they do not sign or "+
			"broadcast a transaction. Token paths must be registered GRC20 "+
			"`realm-path.SYMBOL` keys, and all amount fields use integer base units. "+
			"Approve each input token to the router realm before executing a swap.\n\n"+
			"A route is `inputToken:outputToken:fee` in swap direction. Join "+
			"successive hops with `*POOL*` and separate routes with commas.\n\n"+
			"Exact-in swaps set `amountIn` and protect the output with "+
			"`amountOutMin`; exact-out swaps set `amountOut` and cap spending with "+
			"`amountInMax`. A future Unix `deadline` is required. Multi-route "+
			"`quoteArr` percentages must sum to 100. Single-route "+
			"`sqrtPriceLimitX96` is a decimal price limit; use `0` for no limit.\n\n"+
			"%s",
		chain.PackageAddress("gno.land/r/gnoswap/router"),
		implementation,
		strings.TrimPrefix(implementation, "gno.land"),
		halt.IsHaltedRouter(),
		swapFee,
		maxSwapFeeBPS,
		action,
	)
}
