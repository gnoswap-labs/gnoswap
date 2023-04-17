package gnoswap

import (
	"std"
	"math"
	"internal/big"
	"testing"
	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"

	"gno.land/r/foo"
	"gno.land/r/bar"
)

var (
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	sp01 = testutils.TestAddress("sp01") // Swap Executor 01
	po01 = testutils.TestAddress("po01") // Pool Owner 01
	admin = testutils.TestAddress("admin") // Admin

	rv01 = testutils.TestAddress("rv01") // Receiver 01
	rv02 = testutils.TestAddress("rv02") // Receiver 02
	rv03 = testutils.TestAddress("rv03") // Receiver 03
)


func init() {
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

	std.TestSetOrigCaller(admin)
}


var (
	// Common
	test_tickLower bigint = 200
	test_tickUpper bigint = 45000
	test_liquidityExpect bigint = 1000

	test_tickLower2 bigint = 50000
	test_tickUpper2 bigint = 100000
)


func TestInit(t *testing.T) {
	var (
		// 1			= 0.0001% // XX
		// 500		= 0.05% // USv3 default
		// 3000		= 0.3% // USv3 default
		// 10000	= 1% // USv3 default
		test_fee bigint = 3000
		test_tickSpacing bigint = 100
		test_tick bigint = 43946
		test_sqrtPrice bigint = 8
	)
	Init(
		test_fee, 
		test_tickSpacing, 
		test_sqrtPrice, 
		test_tick,
	)

	std.TestSetOrigCaller(lp01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)

	std.TestSetOrigCaller(sp01)
	foo.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
	bar.Approve(users.AddressOrName(GetOrigPkgAddr()), 50000000)
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

	shouldEQ(t, m1, m11)
	shouldEQ(t, m2, m12)

	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	// tickLower > currentTick X
	Mint(lp01, test_tickLower2, test_tickUpper2, test_liquidityExpect)

	// tickUpper < current tick
	Mint(lp01, -test_tickUpper2, -test_tickLower2, test_liquidityExpect)

	// tickUpper < current_tick
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
	shouldEQ(t, test_liquidity, test_liquidityExpect * 9)

	Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 9)
	test_liquidity = GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	// can't burn when liq is 0
	// (Burn(test_tickLower, test_tickUpper, test_liquidityExpect))
	shouldPanic(t, func() { Burn(test_tickLower, test_tickUpper, test_liquidityExpect) })
}



func TestCollect(t *testing.T) {
	// withdraw all token
	Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	c1, c2 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	c3, c4 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	shouldEQ(t, c1, c3)
	shouldEQ(t, c2, c4)

	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	c5, c6 := Collect(lp01, test_tickLower, test_tickUpper, 100, 100)
	shouldEQ(t, c5, bigint(100))
	shouldEQ(t, c6, bigint(100))
	
	c7, c8 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c7, c3 - bigint(100))
	shouldEQ(t, c8, c4 - bigint(100))


	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	// Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	// no burn => no collect
	c9, c10 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c9, bigint(0))
	shouldEQ(t, c10, bigint(0))

	// burn => some collect
	Burn(test_tickLower, test_tickUpper, test_liquidityExpect * 15)
	c11, c12 := Collect(lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldNEQ(t, c11, bigint(0))
	shouldNEQ(t, c12, bigint(0))
}



func TestSwap(t *testing.T) {
	// 	Swap token0 -> token1
	var test_sqrtPriceExpect bigint = 8 // shuold be same as test_sqrtPrice
	test_slot0 := GetSlot0()

	std.TestSetOrigCaller(lp01)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect * 15)

	std.TestSetOrigCaller(sp01)
	test_price := GetSqrtPrice() - 1
	s1, s2 := Swap(sp01, true, 100000, test_price) // give enough amount to take fees away
	// println("s1:", s1)
	// println("s2:", s2)
	shouldGTE(t, 0, s1 * s2) // token1 will be minus, so 0 shoule always GTE

	var test_minPrice, test_maxPrice bigint
	test_minPrice = (test_price * test_price)
	test_maxPrice = (test_sqrtPriceExpect * test_sqrtPriceExpect)

	test_swapPrice1 := big.Abs(s2) / big.Abs(s1)
	shouldGTE(t, test_swapPrice1, test_minPrice)
	shouldGTE(t, test_maxPrice, test_swapPrice1)

	test_newPrice1 := GetSqrtPrice() - 1
	shouldGTE(t, test_price, test_newPrice1)

	s3, s4 := Swap(sp01, true, 100000, test_newPrice1)
	// println("s3:", s3)
	// println("s4:", s4)
	test_swapPrice2 := big.Abs(s4) / big.Abs(s3)

	test_minPrice = (test_newPrice1) * (test_newPrice1)
	shouldGTE(t, test_swapPrice2, test_minPrice)
	shouldGTE(t, test_maxPrice, test_swapPrice2)

	test_newPrice2 := GetSqrtPrice()
	shouldGTE(t, test_price, test_newPrice2)

	// Swap token1 -> token0
	std.TestSetOrigCaller(sp01)
	ss1, ss2 := Swap(sp01, false, 100000, test_newPrice2 + 1)
	// println("ss1:", ss1)
	// println("ss2:", ss2)
	shouldGTE(t, 0, ss1 * ss2) // token0 will be minus, so 0 shoule always GTE
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



func TestCollectFeeProtocol(t *testing.T) {
	SetFeeProtocol(6, 8)
	test_slot0 := GetSlot0()	
	shouldEQ(t, test_slot0.feeProtocol, bigint(134))

	std.TestSetOrigCaller(lp01)
	Mint(lp01, test_tickLower, test_tickUpper, test_liquidityExpect * 150)

	std.TestSetOrigCaller(sp01)
	Swap(sp01, true, 100000, GetSqrtPrice() - 1) // swap token0 -> token1 => fee only in token0
	Swap(sp01, true, 100000, GetSqrtPrice() - 1) // more protocol fees
	test_fee := GetProtocolFees()

	beforeToken0 := BalanceOf(token0, rv01)
	beforeToken1 := BalanceOf(token1, rv01)

	std.TestSetOrigCaller(sp01)
	CollectFeeProtocol(rv01, 10000, 10000)

	afterToken0 := BalanceOf(token0, rv01)
	afterToken1 := BalanceOf(token1, rv01)

	// no fee for token1 // 0 == before == after
	shouldEQ(t, 0, beforeToken1)
	shouldEQ(t, beforeToken1, afterToken1)

	// some fee for token0
	shouldEQ(t, 0, beforeToken0)
	shouldNEQ(t, bigint(0), afterToken0)
	shouldGTE(t, afterToken0, beforeToken0)
	shouldEQ(t, test_fee.token0 - 1, afterToken0)



	// std.TestSetOrigCaller(sp01)
	Swap(rv02, false, 20, GetSqrtPrice() + 9999) // swap token1 -> token0 // fee will only have token1
	Swap(rv02, false, 20, GetSqrtPrice() + 9999) // more protocol fees
	test_newFee := GetProtocolFees()
	newBeforeToken0 := BalanceOf(token0, rv01)
	newBeforeToken1 := BalanceOf(token1, rv01)

	std.TestSetOrigCaller(sp01)
	CollectFeeProtocol(rv01, 10000, 10000)

	newAfterToken0 := BalanceOf(token0, rv01)
	newAfterToken1 := BalanceOf(token1, rv01)

	// no fee for token 0 
	shouldEQ(t, afterToken0, newBeforeToken0)
	shouldEQ(t, newBeforeToken0, newAfterToken0)

	// some fee for token1
	shouldEQ(t, afterToken1, newBeforeToken1)
	shouldNEQ(t, bigint(0), newAfterToken1)
	shouldGTE(t, newAfterToken1, newBeforeToken1)

	shouldEQ(t, test_newFee.token1 - 1, newAfterToken1)
}