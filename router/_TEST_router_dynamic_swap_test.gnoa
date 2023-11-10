package router

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	_ "gno.land/r/grc20_wrapper"
	p "gno.land/r/pool"
	pos "gno.land/r/position"

	foo "gno.land/r/foo"
	qux "gno.land/r/qux"
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

	p.CreatePool(fooPath, barPath, test_fee100, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	p.CreatePool(barPath, bazPath, test_fee100, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	p.CreatePool(bazPath, quxPath, test_fee100, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176

	p.CreatePool(fooPath, barPath, test_fee500, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	p.CreatePool(barPath, bazPath, test_fee500, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176
	p.CreatePool(bazPath, quxPath, test_fee500, 101729702841318637793976746270) // tick =  5_000, ratio = 1.648680055931176

	p.CreatePool(fooPath, quxPath, test_fee500, 215353707227994575755767921544) // tick = 20_000, ratio = 7.388317279516561
	// foo_bar_baz_qux
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	pos.Mint(fooPath, barPath, test_fee100, int32(4000), int32(6000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)
	pos.Mint(barPath, bazPath, test_fee100, int32(4000), int32(6000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)
	pos.Mint(bazPath, quxPath, test_fee100, int32(4000), int32(6000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)

	pos.Mint(fooPath, barPath, test_fee500, int32(4000), int32(6000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)
	pos.Mint(barPath, bazPath, test_fee500, int32(4000), int32(6000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)
	pos.Mint(bazPath, quxPath, test_fee500, int32(4000), int32(6000), bigint(1000000), bigint(1000000), 0, 0, max_timeout)

	pos.Mint(fooPath, quxPath, test_fee500, int32(19000), int32(21000), bigint(10000), bigint(10000), 0, 0, max_timeout)
}

func TestBestSwapExactInLessRoutes(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	tr01OldFoo := foo.BalanceOf(a2u(tr01))
	tr01OldQux := qux.BalanceOf(a2u(tr01))
	poolOldFoo := foo.BalanceOf(a2u(poolAddr))
	poolOldQux := qux.BalanceOf(a2u(poolAddr))

	// low maxRoutes => can't swap => will panic
	shouldPanicWithMsg(
		t,
		func() { BestSwap("gno.land/r/foo", "gno.land/r/qux", "EXACT_IN", 123_456, 0, 10, 7, 3) },
		"[ROUTER] router.gno__BestSwap() || couldn't finish swap while reaching maximum length of routes",
	)
}

func TestBestSwapExactInMoreRoutes(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	tr01OldFoo := foo.BalanceOf(a2u(tr01))
	tr01OldQux := qux.BalanceOf(a2u(tr01))
	poolOldFoo := foo.BalanceOf(a2u(poolAddr))
	poolOldQux := qux.BalanceOf(a2u(poolAddr))

	BestSwap(
		"gno.land/r/foo", // inputTokenPath
		"gno.land/r/qux", // outputTokenPath
		"EXACT_IN",       // swapType
		123_456,          // amountSpecified
		0,                // sqrtPriceLimitX96
		10,               // distributionPercent
		10,               // maxRoutes
		3,                // maxHops
	)

	tr01NewFoo := foo.BalanceOf(a2u(tr01))
	tr01NewQux := qux.BalanceOf(a2u(tr01))
	poolNewFoo := foo.BalanceOf(a2u(poolAddr))
	poolNewQux := qux.BalanceOf(a2u(poolAddr))

	shouldEQ(t, tr01NewFoo < tr01OldFoo, true)
	shouldEQ(t, tr01OldFoo-tr01NewFoo, 123_456)
	shouldEQ(t, tr01OldQux < tr01NewQux, true)

	shouldEQ(t, poolOldFoo < poolNewFoo, true)
	shouldEQ(t, poolNewFoo-poolOldFoo, 123_456)
	shouldEQ(t, poolNewQux < poolOldQux, true)
}

func TestBestSwapExactOut(t *testing.T) {
	std.TestSetOrigCaller(tr01)

	tr01OldFoo := foo.BalanceOf(a2u(tr01))
	tr01OldQux := qux.BalanceOf(a2u(tr01))
	poolOldFoo := foo.BalanceOf(a2u(poolAddr))
	poolOldQux := qux.BalanceOf(a2u(poolAddr))

	BestSwap(
		"gno.land/r/foo", // inputTokenPath
		"gno.land/r/qux", // outputTokenPath
		"EXACT_OUT",      // swapType
		123_456,          // amountSpecified
		0,                // sqrtPriceLimitX96
		10,               // distributionPercent
		10,               // maxRoutes
		3,                // maxHops
	)

	tr01NewFoo := foo.BalanceOf(a2u(tr01))
	tr01NewQux := qux.BalanceOf(a2u(tr01))
	poolNewFoo := foo.BalanceOf(a2u(poolAddr))
	poolNewQux := qux.BalanceOf(a2u(poolAddr))

	shouldEQ(t, tr01NewFoo < tr01OldFoo, true)
	shouldEQ(t, tr01OldQux < tr01NewQux, true)
	shouldEQ(t, tr01NewQux-tr01OldQux, 123_456)

	shouldEQ(t, poolOldFoo < poolNewFoo, true)
	shouldEQ(t, poolNewQux < poolOldQux, true)
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}
