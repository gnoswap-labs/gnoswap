package router

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"
	pos "gno.land/r/position"

	_ "gno.land/r/bar"
	_ "gno.land/r/baz"
	foo "gno.land/r/foo"
	qux "gno.land/r/qux"
)

var (
	gsa  = testutils.TestAddress("gsa")  // Gnoswap Admin
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

func init() {
	println(gsa, "// gsa")
	println(lp01, "// lp01")
	println(tr01, "// tr01")
	println(poolAddr, "// poolAddr")
	println(posAddr, "// posAddr")
	println(routerAddr, "// routerAddr")
}

func TestInitManual(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	p.InitManual()
	std.TestSkipHeights(1)
}

func TestCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)

	p.CreatePool(fooPath, barPath, test_fee100, 130621891405341611593710811006) // tick = 10_000, ratio = 2.7181459268252253
	p.CreatePool(fooPath, barPath, test_fee500, 167719732170287102368011632179) // tick = 15_000, ratio = 4.481352978667308
	p.CreatePool(barPath, bazPath, test_fee100, 124251697196845557112282348179) // tick =  9_000, ratio = 2.4594924388851824
	p.CreatePool(barPath, quxPath, test_fee100, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	p.CreatePool(bazPath, quxPath, test_fee100, 92049301871182272007977902845)  // tick =  3_000, ratio = 1.3498385611954853
	p.CreatePool(fooPath, quxPath, test_fee100, 965075977353221155028623082916) // tick = 50_000, ratio = 148.37606292307464
	// findSwapPaths("gno.land/r/foo", "gno.land/r/qux")                           // 5 paths
	// foo_qux_100
	// foo_bar_100 > bar_qux_100
	// foo_bar_500 > bar_qux_100
	// foo_bar_100 > bar_baz_100 > baz_qux_100
	// foo_bar_500 > bar_baz_100 > baz_qux_100
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	pos.Mint(fooPath, barPath, test_fee100, int32(9000), int32(11000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(fooPath, barPath, test_fee500, int32(14000), int32(16000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(barPath, bazPath, test_fee100, int32(6000), int32(12000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(barPath, quxPath, test_fee100, int32(4000), int32(6000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)
	pos.Mint(bazPath, quxPath, test_fee100, int32(2000), int32(4000), bigint(10000000), bigint(10000000), 0, 0, max_timeout)

	// direct & expensive
	pos.Mint(fooPath, quxPath, test_fee100, int32(48000), int32(52000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)
}

func TestBestSwapDry(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	tr01FooOldBal := foo.BalanceOf(a2u(tr01))
	tr01QuxOldBal := qux.BalanceOf(a2u(tr01))
	RoQuxOldBal := qux.BalanceOf(a2u(routerAddr))
	PoQuxOldBal := qux.BalanceOf(a2u(poolAddr))

	jsonOutput := BestSwapDry(
		"gno.land/r/foo", // inputTokenPath
		"gno.land/r/qux", // outputTokenPath
		123_456,          // amountIn
		0,                // sqrtPriceLimitX96
	)
	jsonStr := gjson.Parse(jsonOutput)

	shouldEQ(t, jsonStr.Get("totalRoutes").String(), "2")
}

func TestBestSwap(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	tr01FooOldBal := foo.BalanceOf(a2u(tr01))
	tr01QuxOldBal := qux.BalanceOf(a2u(tr01))
	RoQuxOldBal := qux.BalanceOf(a2u(routerAddr))
	PoQuxOldBal := qux.BalanceOf(a2u(poolAddr))

	BestSwap(
		"gno.land/r/foo", // inputTokenPath
		"gno.land/r/qux", // outputTokenPath
		123_456,          // amountIn
		0,                // sqrtPriceLimitX96
	)

	tr01FooNewBal := foo.BalanceOf(a2u(tr01))
	tr01QuxNewBal := qux.BalanceOf(a2u(tr01))
	RoQuxNewBal := qux.BalanceOf(a2u(routerAddr))
	PoQuxNewBal := qux.BalanceOf(a2u(poolAddr))

	shouldEQ(t, RoQuxOldBal, RoQuxNewBal)
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}
