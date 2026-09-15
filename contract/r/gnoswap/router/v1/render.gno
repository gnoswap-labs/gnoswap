package router

import (
	"chain"
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt/v1"
	"gno.land/r/gnoswap/router"
)

const maxSwapFeeBPS uint64 = 1000

func (r *routerV1) Render(path string) string {
	var action string
	switch path {
	case "":
		action = md.H3("Exact-input single-route swap") + "\n" +
			"<gno-form exec=\"ExactInSingleSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Approved input: gno.land/r/gnoland/wugnot.wugnot\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Output: gno.land/r/gnoswap/test_token/test_usdc.USDC\" required=\"true\" />\n" +
			"  <gno-input name=\"amountIn\" type=\"text\" placeholder=\"Exact input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Route: inputToken:outputToken:500\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOutMin\" type=\"text\" placeholder=\"Minimum output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"sqrtPriceLimitX96\" type=\"text\" placeholder=\"Q64.96 sqrt-price limit (0 = no limit)\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Future Unix timestamp (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	case "swap/exact-in":
		action = md.H3("Exact-input multi-route swap") + "\n" +
			"<gno-form exec=\"ExactInSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Approved input: gno.land/r/gnoland/wugnot.wugnot\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Output: gno.land/r/gnoswap/test_token/test_usdc.USDC\" required=\"true\" />\n" +
			"  <gno-input name=\"amountIn\" type=\"text\" placeholder=\"Exact input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Routes: A:C:500,A:B:500*POOL*B:C:3000 (A/B/C = token keys)\" required=\"true\" />\n" +
			"  <gno-input name=\"quoteArr\" type=\"text\" placeholder=\"Route percentages: 100 or 70,30 (total 100)\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOutMin\" type=\"text\" placeholder=\"Minimum output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Future Unix timestamp (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	case "swap/exact-out":
		action = md.H3("Exact-output multi-route swap") + "\n" +
			"<gno-form exec=\"ExactOutSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Approved input: gno.land/r/gnoland/wugnot.wugnot\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Output: gno.land/r/gnoswap/test_token/test_usdc.USDC\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOut\" type=\"text\" placeholder=\"Exact output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Routes: A:C:500,A:B:500*POOL*B:C:3000 (A/B/C = token keys)\" required=\"true\" />\n" +
			"  <gno-input name=\"quoteArr\" type=\"text\" placeholder=\"Route percentages: 100 or 70,30 (total 100)\" required=\"true\" />\n" +
			"  <gno-input name=\"amountInMax\" type=\"text\" placeholder=\"Maximum input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Future Unix timestamp (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	case "swap/exact-out-single":
		action = md.H3("Exact-output single-route swap") + "\n" +
			"<gno-form exec=\"ExactOutSingleSwapRoute\">\n" +
			"  <gno-input name=\"inputToken\" type=\"text\" placeholder=\"Approved input: gno.land/r/gnoland/wugnot.wugnot\" required=\"true\" />\n" +
			"  <gno-input name=\"outputToken\" type=\"text\" placeholder=\"Output: gno.land/r/gnoswap/test_token/test_usdc.USDC\" required=\"true\" />\n" +
			"  <gno-input name=\"amountOut\" type=\"text\" placeholder=\"Exact output amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"routeArr\" type=\"text\" placeholder=\"Route: inputToken:outputToken:500\" required=\"true\" />\n" +
			"  <gno-input name=\"amountInMax\" type=\"text\" placeholder=\"Maximum input amount (base units)\" required=\"true\" />\n" +
			"  <gno-input name=\"sqrtPriceLimitX96\" type=\"text\" placeholder=\"Q64.96 sqrt-price limit (0 = no limit)\" required=\"true\" />\n" +
			"  <gno-input name=\"deadline\" type=\"number\" placeholder=\"Future Unix timestamp (seconds)\" required=\"true\" />\n" +
			"  <gno-input name=\"referrer\" type=\"text\" placeholder=\"Optional referrer address\" />\n" +
			"</gno-form>\n"
	default:
		return "404\n"
	}

	swapFee := r.GetSwapFee()
	implementation := router.GetImplementationPackagePath()
	statusTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Router package", md.Link("gno.land/r/gnoswap/router", "/r/gnoswap/router")},
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/router").String())},
			{"Active implementation", md.Link(implementation, strings.TrimPrefix(implementation, "gno.land"))},
			{"Router halted", ufmt.Sprintf("%t", halt.IsHaltedRouter())},
		},
	}
	feeTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Swap fee", ufmt.Sprintf("%d bps", swapFee)},
			{"Maximum swap fee", ufmt.Sprintf("%d bps (10%%)", maxSwapFeeBPS)},
			{"Fee unit", "1 bps = 0.01% of the output-token amount"},
			{"Amount unit", "Integer token base units; decimals are token-specific"},
		},
	}

	out := md.H1("Gnoswap Router") + "\n"
	out += md.H2("Router status") + "\n"
	out += statusTable.String() + "\n"
	out += md.H2("Swap fee configuration") + "\n"
	out += feeTable.String() + "\n"
	out += md.H2("Swap") + "\n"
	out += md.Paragraph(
		md.Link("Exact input: single route", "/r/gnoswap/router") + " · " +
			md.Link("Exact input: multiple routes", "/r/gnoswap/router:swap/exact-in") + " · " +
			md.Link("Exact output: single route", "/r/gnoswap/router:swap/exact-out-single") + " · " +
			md.Link("Exact output: multiple routes", "/r/gnoswap/router:swap/exact-out"),
	)
	out += action
	return out
}
