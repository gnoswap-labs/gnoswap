package gnoswap

import (
	"math"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"

	bar "gno.land/r/bar"
	foo "gno.land/r/foo"
)

var (
	gsa = testutils.TestAddress("gsa") // Gnoswap Admin

	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	lp02 = testutils.TestAddress("lp02") // Liquidity Provider 02

	tr01 = testutils.TestAddress("tr01") // Trader 01
)

func init() {
	std.TestSetOrigCaller(lp01)
	foo.FaucetL()
	bar.FaucetL()

	std.TestSetOrigCaller(lp02)
	foo.FaucetL()
	bar.FaucetL()

	std.TestSetOrigCaller(tr01)
	foo.FaucetL()
	bar.FaucetL()

	// debug - print addr
	println(lp01, "// lp01")
	println(lp02, "// lp02")
	println(tr01, "// tr01")
	println(GetOrigPkgAddr(), "// pool")
}

var (
	// Common
	pToken0        = "foo"
	pToken1        = "bar"
	pFee    bigint = 500

	test_tickLower       bigint = 9000
	test_tickUpper       bigint = 11000
	test_liquidityExpect bigint = 1000
)

// 1. Init & Create Pool using Factory Contract by gsa
func TestFactoryCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	Init()
	CreatePool("foo", "bar", pFee, 130622891405341611593710811006)
	// 130621891405341611593710811006 // 9999
	// 130622891405341611593710811006 // 10000

	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { CreatePool("foo", "bar", 500, 130621891405341611593710811006) })

	// Approve
	std.TestSetOrigCaller(lp01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(lp01), 50000000)
	bar.Approve(users.AddressOrName(lp01), 50000000)

	std.TestSetOrigCaller(lp02)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(lp02), 50000000)
	bar.Approve(users.AddressOrName(lp02), 50000000)

	std.TestSetOrigCaller(tr01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(tr01), 50000000)
	bar.Approve(users.AddressOrName(tr01), 50000000)
}

// Swap by tr01, Mint by lp01 ~ 02
func TestSwap(t *testing.T) {
	pool := GetPool(pToken0, pToken1, pFee)

	// lp01 mint 9000 ~ 11000 tick range
	std.TestSetOrigCaller(lp01)
	m11, m12 := Mint(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, test_liquidityExpect*10000)

	// lp02 mint (almost) full range
	// fee 500 will use tickSpacing 10
	// MIN_TICK bigint = -887272
	// MAX_TICK bigint = 887272

	std.TestSetOrigCaller(lp02)
	m21, m22 := Mint(pToken0, pToken1, pFee, lp02, MIN_TICK+2, MAX_TICK-2, test_liquidityExpect*10000)

	println("Concentrated Mint")
	println("> lp01 mint", m11, m12)
	println()

	println("Full Mint")
	println("> lp02 mint", m21, m22)
	println()

	printBalance()
	println("###################################################################################")
	println()

	test_price_01 := bigint(MIN_SQRT_RATIO + 1) // maximum price
	test_price_10 := bigint(MAX_SQRT_RATIO - 1) // minimum price

	{
		println("Swap #1")
		println("> direction: token0 -> token1")
		// println("> amount: 10000")
		println()

		// balance before swap
		poolOldToken0Bal := BalanceOf(pool.token0, GetOrigPkgAddr())
		poolOldToken1Bal := BalanceOf(pool.token1, GetOrigPkgAddr())

		tr01OldToken0Bal := BalanceOf(pool.token0, tr01)
		tr01OldToken1Bal := BalanceOf(pool.token1, tr01)

		lp01OldToken0Bal := BalanceOf(pool.token0, lp01)
		lp01OldToken1Bal := BalanceOf(pool.token1, lp01)

		lp02OldToken0Bal := BalanceOf(pool.token0, lp02)
		lp02OldToken1Bal := BalanceOf(pool.token1, lp02)

		// SWAP
		std.TestSetOrigCaller(tr01)
		// s0, s1 := Swap(pToken0, pToken1, pFee, tr01, true, bigint(600000), test_price_01)  // 9034
		// s0, s1 := Swap(pToken0, pToken1, pFee, tr01, true, bigint(650000), test_price_01) // 8955
		// println("Current Tick:", pool.GetPoolSlot0Tick())

		// s0, s1 := Swap(pToken0, pToken1, pFee, tr01, true, bigint(620000), test_price_01) // one iteration - yes fee
		s0, s1 := Swap(pToken0, pToken1, pFee, tr01, true, bigint(630000), test_price_01) // one iteration - no fee

		// s0, s1 := Swap(pToken0, pToken1, pFee, tr01, true, bigint(1400000), test_price_01) // one iteration - no fee
		// s0, s1 := Swap(pToken0, pToken1, pFee, tr01, true, bigint(1500000), test_price_01) // two iteration
		shouldNEQ(t, s0, bigint(0))
		shouldNEQ(t, s1, bigint(0))

		// balance after swap
		poolNewToken0Bal := BalanceOf(pool.token0, GetOrigPkgAddr())
		poolNewToken1Bal := BalanceOf(pool.token1, GetOrigPkgAddr())

		tr01NewToken0Bal := BalanceOf(pool.token0, tr01)
		tr01NewToken1Bal := BalanceOf(pool.token1, tr01)

		lp01NewToken0Bal := BalanceOf(pool.token0, lp01)
		lp01NewToken1Bal := BalanceOf(pool.token1, lp01)

		lp02NewToken0Bal := BalanceOf(pool.token0, lp02)
		lp02NewToken1Bal := BalanceOf(pool.token1, lp02)

		println("Balance pool")
		println("> token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
		println("> token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")
		println()

		println("Balance tr01")
		println("> token0:", tr01OldToken0Bal, "->", tr01NewToken0Bal, "( diff:", tr01NewToken0Bal-tr01OldToken0Bal, ")")
		println("> token1:", tr01OldToken1Bal, "->", tr01NewToken1Bal, "( diff:", tr01NewToken1Bal-tr01OldToken1Bal, ")")
		println()

		// To collect fee wihout removing liquidity
		// burn 0
		// then collect

		std.TestSetOrigCaller(lp01)
		Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, 0)
		c1, c2 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 100000000, 100000000)
		println("Fee lp01")
		println("> token0:", c1)
		println("> token1:", c2)
		println()

		std.TestSetOrigCaller(lp02)
		Burn(pToken0, pToken1, pFee, MIN_TICK+2, MAX_TICK-2, 0)
		c3, c4 := Collect(pToken0, pToken1, pFee, lp02, MIN_TICK+2, MAX_TICK-2, 100000000, 100000000)
		println("Fee lp02")
		println("> token0:", c3)
		println("> token1:", c4)
		println()

	}
}

func printBalance() {
	pool := GetPool(pToken0, pToken1, pFee)

	println("Balance lp01")
	println("> token0:", BalanceOf(pool.token0, lp01))
	println("> token1:", BalanceOf(pool.token1, lp01))
	println()

	println("Balance lp02")
	println("> token0:", BalanceOf(pool.token0, lp02))
	println("> token1:", BalanceOf(pool.token1, lp02))
	println()

	println("Balance pool")
	println("> token0:", BalanceOf(pool.token0, GetOrigPkgAddr()))
	println("> token1:", BalanceOf(pool.token1, GetOrigPkgAddr()))
	println()
}

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
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
