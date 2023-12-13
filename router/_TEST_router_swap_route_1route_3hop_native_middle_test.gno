package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/demo/grc20_wrapper"
	pl "gno.land/r/demo/pool"
	pos "gno.land/r/demo/position"
)

var (
	pc01 = testutils.TestAddress("pc01") // Pool Creator 01
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	tr01 = testutils.TestAddress("tr01") // Trader 01

	poolAddr   = std.DerivePkgAddr("gno.land/r/demo/pool")
	posAddr    = std.DerivePkgAddr("gno.land/r/demo/position")
	routerAddr = std.DerivePkgAddr("gno.land/r/demo/router")
)

var (
	// Common
	barPath  = "gno.land/r/demo/bar"
	gnsPath  = "gno.land/r/demo/gns"
	gnotPath = "gnot"

	MAX_TIMEOUT bigint = 9999999999
)

// debug addr
func init() {
	println(pc01, "// pc01")
	println(lp01, "// lp01")
	println(tr01, "// tr01")
	println(poolAddr, "// pool")
	println(posAddr, "// pos")
	println(routerAddr, "// router")
}

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(pc01)
	pl.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(pc01)

	// gns > bar

	// gns:gnot
	// gnot:bar

	pl.CreatePool(gnsPath, gnotPath, uint16(100), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	pl.CreatePool(gnotPath, barPath, uint16(100), 130621891405341611593710811006) // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875
	// 1 gns ≈ 7.29 bar

	jsonOutput := pl.ApiGetPools()
	jsonStr := gjson.Parse(jsonOutput)
	shouldEQ(t, len(jsonStr.Get("response.data").Array()), 2)
}

func TestPositionMintGnsGnot(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 99999)

	// send
	std.TestSetOrigSend(std.Coins{{"ugnot", 99999}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 99999)

	tokenId, liquidity, amount0, amount1 := pos.Mint(gnsPath, gnotPath, uint16(100), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, MAX_TIMEOUT)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, amount0 > 0, true) // 36789
	shouldEQ(t, amount1 > 0, true) // 99999
}

func TestPositionMintGnotBar(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(std.GetOrigCaller(), "ugnot", 99999)

	// send
	std.TestSetOrigSend(std.Coins{{"ugnot", 99999}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 99999)

	tokenId, liquidity, amount0, amount1 := pos.Mint(gnotPath, barPath, uint16(100), int32(9000), int32(11000), bigint(100_000), bigint(100_000), 0, 0, MAX_TIMEOUT)
	shouldEQ(t, tokenId, uint64(2))
	shouldEQ(t, amount0 > 0, true) // 99999
	shouldEQ(t, amount1 > 0, true) // 36865
}

func TestDrySwapRouteBarGnotExactIn(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	dryResult := DrySwapRoute(
		gnsPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/gns:gnot:100*POOL*gnot:gno.land/r/demo/bar:100", // strRouteArr
		"100", // quoteArr
	)
	shouldEQ(t, dryResult, bigint(7339))
}

func TestSwapRouteBarGnotExactIn(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	std.TestSetOrigSend(std.Coins{{"", 0}}, nil)
	swapResult := SwapRoute(
		gnsPath,      // inputToken
		barPath,      // outputToken
		bigint(1000), // amountSpecified
		"EXACT_IN",   // swapType
		"gno.land/r/demo/gns:gnot:100*POOL*gnot:gno.land/r/demo/bar:100", // strRouteArr
		"100", // quoteArr
		"0",   // tokenAmountLimit
	)
	shouldEQ(t, swapResult, bigint(7339))
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}
