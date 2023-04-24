package gnoswap

import (
	"math"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"

	"gno.land/r/bar"
	"gno.land/r/foo"
)

var (
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	sp01 = testutils.TestAddress("sp01") // Swap Executor 01
	gso  = testutils.TestAddress("gso")  // GnoSwap Owner
)

func init() {
	// DEBUG ADDR
	println(lp01, "lp01")
	println(sp01, "sp01")
	println(gso, "gso")
	println(GetOrigPkgAddr(), "pool")
	println()

	std.TestSetOrigCaller(lp01)
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()

	std.TestSetOrigCaller(sp01)
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
}

var (
	// Common
	test_tickLower       bigint = 9000
	test_tickUpper       bigint = 11000
	test_liquidityExpect bigint = 1000

	test_tickLower2 bigint = 50000
	test_tickUpper2 bigint = 100000
)

func TestInit(t *testing.T) {
	var (
		// 500		= 0.05% // USv3 default
		// 3000		= 0.3% // USv3 default
		// 10000	= 1% // USv3 default
		test_fee bigint = 3000

		test_tickSpacing bigint = 10
		test_sqrtPrice   bigint = 130621891405341611593710811006 // tick = 10000
	)
	Init(
		test_fee,
		test_tickSpacing,
		test_sqrtPrice,
	)

	std.TestSetOrigCaller(lp01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(lp01), 50000000)
	bar.Approve(users.AddressOrName(lp01), 50000000)

	std.TestSetOrigCaller(sp01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	foo.Approve(users.AddressOrName(sp01), 50000000)
	bar.Approve(users.AddressOrName(sp01), 50000000)
}

func TestBeforeBalance(t *testing.T) {
	println("=============================== Before All Swap")
	PrintUserBalance("lp01", lp01) // Liquidity Provider
	println()

	PrintUserBalance("sp01", sp01) // Swap Exector
	println()

	PrintUserBalance("gso", gso) // GnoSwap Owner
	println()

	PrintUserBalance("pool", GetOrigPkgAddr())
	println()
}

func TestMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)

	test_liquidity := GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	m1, m2 := Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	m11, m12 := Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)

	shouldNEQ(t, m1, bigint(0))
	shouldNEQ(t, m2, bigint(0))
	shouldEQ(t, m1, m11)
	shouldEQ(t, m2, m12)

	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	// tickLower > currentTick || dont' add to current liquidity
	Mint(lp01, test_tickLower2, test_tickUpper2, test_liquidityExpect)

	// tickUpper < current tick || dont' add to current liquidity
	Mint(lp01, -test_tickUpper2, -test_tickLower2, test_liquidityExpect)

	// tickUpper < current_tick || dont' add to current liquidity
	Mint(lp01, -test_tickUpper, -test_tickLower, test_liquidityExpect)

	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect)
	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*20)
}

func TestBurn(t *testing.T) {
	b1, b2 := Burn(test_tickLower, test_tickUpper, test_liquidityExpect)
	b11, b12 := Burn(test_tickLower, test_tickUpper, test_liquidityExpect)
	shouldEQ(t, b1, b11)
	shouldEQ(t, b2, b12)

	test_liquidity := GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*18)

	Burn(test_tickLower, test_tickUpper, test_liquidityExpect*8)
	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	Burn(test_tickLower, test_tickUpper, 1)
	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(9999))

	Burn(test_tickLower, test_tickUpper, bigint(999))
	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*9)

	Burn(test_tickLower, test_tickUpper, test_liquidityExpect*9)
	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	// can't burn when liq is 0
	// (Burn(test_tickLower, test_tickUpper, test_liquidityExpect))
	shouldPanic(t, func() { Burn(test_tickLower, test_tickUpper, test_liquidityExpect) })
}

func TestCollect(t *testing.T) {
	// withdraw all token
	Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c1, c2 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c3, c4 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	shouldEQ(t, c1, c3)
	shouldEQ(t, c2, c4)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c5, c6 := Collect(lp01, test_tickLower, test_tickUpper, 100, 100)
	shouldEQ(t, c5, bigint(100))
	shouldEQ(t, c6, bigint(100))

	c7, c8 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c7, c3-bigint(100))
	shouldEQ(t, c8, c4-bigint(100))

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	// Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	// no burn => no collect
	c9, c10 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c9, bigint(0))
	shouldEQ(t, c10, bigint(0))

	// burn => some collect
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c11, c12 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldNEQ(t, c11, bigint(0))
	shouldNEQ(t, c12, bigint(0))
}

func TestSwap(t *testing.T) {
	// 	Swap token0 -> token1
	var test_sqrtPriceExpect bigint = GetSqrtPriceX96() // shuold be same as test_sqrtPrice
	test_slot0 := GetSlot0()

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect*1000)

	std.TestSetOrigCaller(sp01)
	// test_price := GetSqrtPriceX96() - 1
	test_price := bigint(MIN_SQRT_RATIO + 1)

	{
		// println("SWAP 10000, FROM token0, TO token1")
		// println("====Before Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		userToken0Bal := BalanceOf(token0, sp01)
		userToken1Bal := BalanceOf(token1, sp01)
		poolToken0Bal := BalanceOf(token0, GetOrigPkgAddr())
		poolToken1Bal := BalanceOf(token1, GetOrigPkgAddr())

		amount0, amount1 := Swap(sp01, true, 10000, test_price) // give enough amount to take fees away
		// println("amount0:", amount0)
		// println("amount1:", amount1)
		// println()

		shouldEQ(t, userToken0Bal-amount0, BalanceOf(token0, sp01))
		shouldEQ(t, userToken1Bal-amount1, BalanceOf(token1, sp01))
		// shouldEQ(t, poolToken0Bal + amount0, BalanceOf(token0, GetOrigPkgAddr()))
		// shouldEQ(t, poolToken1Bal + amount1, BalanceOf(token1, GetOrigPkgAddr()))

		// println("====After Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		// println()
	}

	{
		// println("SWAP 5000, FROM token0, TO token1")
		// println("====Before Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		userToken0Bal := BalanceOf(token0, sp01)
		userToken1Bal := BalanceOf(token1, sp01)
		poolToken0Bal := BalanceOf(token0, GetOrigPkgAddr())
		poolToken1Bal := BalanceOf(token1, GetOrigPkgAddr())

		amount0, amount1 := Swap(sp01, true, 5000, test_price) // give enough amount to take fees away

		shouldEQ(t, userToken0Bal-amount0, BalanceOf(token0, sp01))
		shouldEQ(t, userToken1Bal-amount1, BalanceOf(token1, sp01))
		shouldEQ(t, poolToken0Bal+amount0, BalanceOf(token0, GetOrigPkgAddr()))
		shouldEQ(t, poolToken1Bal+amount1, BalanceOf(token1, GetOrigPkgAddr()))

		// println("====After Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		// println()
	}

	{
		// println("SWAP 1000, FROM token0, TO token1")
		// println("====Before Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		userToken0Bal := BalanceOf(token0, sp01)
		userToken1Bal := BalanceOf(token1, sp01)
		poolToken0Bal := BalanceOf(token0, GetOrigPkgAddr())
		poolToken1Bal := BalanceOf(token1, GetOrigPkgAddr())

		amount0, amount1 := Swap(sp01, true, 1000, test_price) // give enough amount to take fees away

		shouldEQ(t, userToken0Bal-amount0, BalanceOf(token0, sp01))
		shouldEQ(t, userToken1Bal-amount1, BalanceOf(token1, sp01))
		shouldEQ(t, poolToken0Bal+amount0, BalanceOf(token0, GetOrigPkgAddr()))
		shouldEQ(t, poolToken1Bal+amount1, BalanceOf(token1, GetOrigPkgAddr()))

		// println("====After Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		// println()
	}

	// Swap token1 -> token0
	{
		// println("SWAP 10000, FROM token1, TO token0")
		// println("====Before Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		userToken0Bal := BalanceOf(token0, sp01)
		userToken1Bal := BalanceOf(token1, sp01)
		poolToken0Bal := BalanceOf(token0, GetOrigPkgAddr())
		poolToken1Bal := BalanceOf(token1, GetOrigPkgAddr())
		amount0, amount1 := Swap(sp01, false, 16000, bigint(MAX_SQRT_RATIO-1)) // give enough amount to take fees away

		shouldEQ(t, userToken0Bal-amount0, BalanceOf(token0, sp01))
		shouldEQ(t, userToken1Bal-amount1, BalanceOf(token1, sp01))
		shouldEQ(t, poolToken0Bal+amount0, BalanceOf(token0, GetOrigPkgAddr()))
		shouldEQ(t, poolToken1Bal+amount1, BalanceOf(token1, GetOrigPkgAddr()))

		// println("====After Balance====")
		// PrintUserBalance("sp01", sp01)
		// PrintUserBalance("pool", GetOrigPkgAddr())
		// println()
		// println()
	}
}

func TestSetFeeProtocol(t *testing.T) {
	test_slot0 := GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(0))

	SetFeeProtocol(0, 0)
	test_slot0 = GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(0))

	SetFeeProtocol(0, 4)
	test_slot0 = GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(64))

	SetFeeProtocol(4, 0)
	test_slot0 = GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(4))

	SetFeeProtocol(6, 8)
	test_slot0 = GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(134))

	// out of pre-defined range
	shouldPanic(t, func() { SetFeeProtocol(2, 2) })
}

func TestCollectProtocol(t *testing.T) {
	SetFeeProtocol(6, 8)
	test_slot0 := GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(134))

	std.TestSetOrigCaller(lp01)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect*150)

	{
		// println("SWAP 1000000, FROM token0, TO token1")
		// println("SWAP 1000000, FROM token0, TO token1")
		// println("====Before Balance====")
		// PrintUserBalance("gso", gso)
		// println()

		recvToken0Bal := BalanceOf(token0, gso)
		recvToken1Bal := BalanceOf(token1, gso)

		std.TestSetOrigCaller(sp01)
		Swap(sp01, true, 100000, bigint(MIN_SQRT_RATIO+1)) // swap token0 -> token1 => fee only in token0
		Swap(sp01, true, 100000, bigint(MIN_SQRT_RATIO+1)) // more protocol fees

		amount0, amount1 := CollectProtocol(gso, 100000, 100000)
		// println("====After Balance====")
		// PrintUserBalance("gso", gso)

		shouldEQ(t, recvToken0Bal+amount0, BalanceOf(token0, gso))
		shouldEQ(t, recvToken1Bal+amount1, BalanceOf(token1, gso))
	}

	{
		// println("SWAP 1000000, FROM token1, TO token0")
		// println("====Before Balance====")
		// PrintUserBalance("gso", gso)
		// println()

		recvToken0Bal := BalanceOf(token0, gso)
		recvToken1Bal := BalanceOf(token1, gso)

		std.TestSetOrigCaller(sp01)
		Swap(sp01, false, 100000, bigint(MAX_SQRT_RATIO-1)) // swap token0 -> token1 => fee only in token0

		amount0, amount1 := CollectProtocol(gso, 100000, 100000)
		// println("====After Balance====")
		// PrintUserBalance("gso", gso)

		shouldEQ(t, recvToken0Bal+amount0, BalanceOf(token0, gso))
		shouldEQ(t, recvToken1Bal+amount1, BalanceOf(token1, gso))
	}
}

func TestAfterBalance(t *testing.T) {
	println("=============================== After All Swap")
	PrintUserBalance("lp01", lp01) // Liquidity Provider
	println()

	PrintUserBalance("sp01", sp01) // Swap Exector
	println()

	PrintUserBalance("gso", gso) // GnoSwap Owner
	println()

	PrintUserBalance("pool", GetOrigPkgAddr())
	println()
}

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

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
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
