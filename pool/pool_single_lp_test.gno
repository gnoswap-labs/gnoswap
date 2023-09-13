package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
)

var (
	gsa  = testutils.TestAddress("gsa")  // Gnoswap Admin
	lp01 = testutils.TestAddress("lp01") // Liquidity Provider 01
	tr01 = testutils.TestAddress("tr01") // Trader 01

	posAddr = std.DerivePkgAddr("gno.land/r/position")

	poolPath = "gno.land/r/pool"
)

func init() {
	// debug - print addr
	// println(gsa, "// gsa")
	// println(lp01, "// lp01")
	// println(tr01, "// tr01")
	// println(GetOrigPkgAddr(), "// pool")
	// println(std.DerivePkgAddr(poolPath), "// PrevRealm // pool")
}

var (
	// Common
	pToken0 = "foo"
	pToken1 = "bar"
	pFee    = uint16(500)

	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)

	test_tickLower2 = int32(50000)
	test_tickUpper2 = int32(100000)
)

// 1. Init & Create Pool using Factory Contract by Gnoswap Admin
func TestInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(gsa)
	InitManual()
	CreatePool("foo", "bar", pFee, 130621891405341611593710811006)

	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { CreatePool("foo", "bar", 500, 130621891405341611593710811006) })
}

// 2. Mint by lp01
func TestMint(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/position")
	std.TestSetOrigCaller(lp01)

	Mint(
		pToken0,
		pToken1,
		pFee,
		posAddr,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpect,
	)

	pool := GetPool(pToken0, pToken1, pFee)
	test_liquidity := pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect)

	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)

	m81, m82 := Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	m101, m102 := Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)

	shouldNEQ(t, m81, bigint(0))
	shouldNEQ(t, m82, bigint(0))
	shouldEQ(t, m81, m101)
	shouldEQ(t, m82, m102)

	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	// tickLower > currentTick == don't add to current liquidity
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower2, test_tickUpper2, test_liquidityExpect)

	// tickUpper < current tick == don't add to current liquidity
	Mint(pToken0, pToken1, pFee, posAddr, -test_tickUpper2, -test_tickLower2, test_liquidityExpect)

	// tickUpper < tickLower == don't add to current liquidity
	Mint(pToken0, pToken1, pFee, posAddr, -test_tickUpper, -test_tickLower, test_liquidityExpect)

	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)

	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*20)
}

// 3. Burn by lp01
func TestBurn(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/position")
	std.TestSetOrigCaller(lp01)

	b11, b12 := Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect)
	b21, b22 := Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect)
	shouldEQ(t, b11, b21)
	shouldEQ(t, b12, b22)

	pool := GetPool(pToken0, pToken1, pFee)
	test_liquidity := pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*18)

	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*8)
	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, 1)
	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(9999))

	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, 999)
	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*9)

	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*9)
	test_liquidity = pool.GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	// can't burn when liq is 0
	// Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect)
	shouldPanic(t, func() { Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect) })
}

// 4. Collect
func TestCollect(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/position")
	std.TestSetOrigCaller(lp01)

	// withdraw all token before test `Collect`
	Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	// pool should have zero liquidity
	pool := GetPool(pToken0, pToken1, pFee)
	test_liquidity := pool.GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c11, c12 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c21, c22 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 50000000, 50000000)

	shouldEQ(t, c11, c21)
	shouldEQ(t, c12, c22)

	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c31, c32 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 100, 100)
	shouldEQ(t, c31, bigint(100))
	shouldEQ(t, c32, bigint(100))

	c41, c42 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c41, c21-bigint(100))
	shouldEQ(t, c42, c22-bigint(100))

	// Mint > No Burn => nothing to collect
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	// Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c51, c52 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c51, bigint(0))
	shouldEQ(t, c52, bigint(0))

	// Burn Now => something to collect
	Burn(pToken0, pToken1, pFee, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c61, c62 := Collect(pToken0, pToken1, pFee, lp01, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldNEQ(t, c61, bigint(0))
	shouldNEQ(t, c62, bigint(0))
}

// 5. Swap by tr01
func TestSwap(t *testing.T) {
	pool := GetPool(pToken0, pToken1, pFee)
	test_liquidity := pool.GetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	std.TestSetPrevRealm("gno.land/r/position")
	std.TestSetOrigCaller(lp01)
	Mint(pToken0, pToken1, pFee, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*20000)

	// Swap several times
	std.TestSetOrigCaller(tr01)
	test_price := bigint(MIN_SQRT_RATIO + 1) // maximum price

	{
		println("Swap #1")
		println("> direction: token0 -> token1")
		println("> amount: 10000")

		poolOldToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolOldToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userOldToken0Bal := balanceOf(pool.token0, tr01)
		userOldToken1Bal := balanceOf(pool.token1, tr01)

		amount0, amount1 := Swap(
			pToken0,
			pToken1,
			pFee,
			tr01,
			true,
			bigint(10000),
			test_price,
		)

		shouldNEQ(t, amount0, bigint(0))
		shouldNEQ(t, amount1, bigint(0))

		poolNewToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolNewToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userNewToken0Bal := balanceOf(pool.token0, tr01)
		userNewToken1Bal := balanceOf(pool.token1, tr01)

		shouldEQ(t, userOldToken0Bal-amount0, userNewToken0Bal)
		shouldEQ(t, userOldToken1Bal-amount1, userNewToken1Bal)
		shouldEQ(t, poolOldToken0Bal+amount0, poolNewToken0Bal)
		shouldEQ(t, poolOldToken1Bal+amount1, poolNewToken1Bal)

		println("Pool")
		println("> token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
		println("> token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

		println("Trader tr01")
		println("> token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
		println("> token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
		println()
	}

	{
		println("Swap #2")
		println("> direction: token0 -> token1")
		println("> amount: 5000")

		poolOldToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolOldToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userOldToken0Bal := balanceOf(pool.token0, tr01)
		userOldToken1Bal := balanceOf(pool.token1, tr01)

		amount0, amount1 := Swap(pToken0, pToken1, pFee, tr01, true, 5000, test_price) // give enough amount to take fees away

		poolNewToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolNewToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userNewToken0Bal := balanceOf(pool.token0, tr01)
		userNewToken1Bal := balanceOf(pool.token1, tr01)

		shouldEQ(t, userOldToken0Bal-amount0, userNewToken0Bal)
		shouldEQ(t, userOldToken1Bal-amount1, userNewToken1Bal)
		shouldEQ(t, poolOldToken0Bal+amount0, poolNewToken0Bal)
		shouldEQ(t, poolOldToken1Bal+amount1, poolNewToken1Bal)

		println("Pool")
		println("> token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
		println("> token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

		println("Trader tr01")
		println("> token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
		println("> token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
		println()
	}

	{
		println("Swap #3")
		println("> direction: token0 -> token1")
		println("> amount: 1000")

		poolOldToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolOldToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userOldToken0Bal := balanceOf(pool.token0, tr01)
		userOldToken1Bal := balanceOf(pool.token1, tr01)

		amount0, amount1 := Swap(pToken0, pToken1, pFee, tr01, true, 1000, test_price) // give enough amount to take fees away

		poolNewToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolNewToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userNewToken0Bal := balanceOf(pool.token0, tr01)
		userNewToken1Bal := balanceOf(pool.token1, tr01)

		shouldEQ(t, userOldToken0Bal-amount0, userNewToken0Bal)
		shouldEQ(t, userOldToken1Bal-amount1, userNewToken1Bal)
		shouldEQ(t, poolOldToken0Bal+amount0, poolNewToken0Bal)
		shouldEQ(t, poolOldToken1Bal+amount1, poolNewToken1Bal)

		println("Pool")
		println("> token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
		println("> token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

		println("Trader tr01")
		println("> token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
		println("> token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
		println()
	}

	// Swap token1 -> token0
	{
		println("Swap #4")
		println("> direction: token1 -> token0")
		println("> amount: 16000")

		poolOldToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolOldToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userOldToken0Bal := balanceOf(pool.token0, tr01)
		userOldToken1Bal := balanceOf(pool.token1, tr01)

		amount0, amount1 := Swap(pToken0, pToken1, pFee, tr01, false, 16000, (MAX_SQRT_RATIO - 1)) // give enough amount to take fees away

		poolNewToken0Bal := balanceOf(pool.token0, GetOrigPkgAddr())
		poolNewToken1Bal := balanceOf(pool.token1, GetOrigPkgAddr())

		userNewToken0Bal := balanceOf(pool.token0, tr01)
		userNewToken1Bal := balanceOf(pool.token1, tr01)

		shouldEQ(t, userOldToken0Bal-amount0, userNewToken0Bal)
		shouldEQ(t, userOldToken1Bal-amount1, userNewToken1Bal)
		shouldEQ(t, poolOldToken0Bal+amount0, poolNewToken0Bal)
		shouldEQ(t, poolOldToken1Bal+amount1, poolNewToken1Bal)

		println("Pool")
		println("> token0:", poolOldToken0Bal, "->", poolNewToken0Bal, "( diff:", poolNewToken0Bal-poolOldToken0Bal, ")")
		println("> token1:", poolOldToken1Bal, "->", poolNewToken1Bal, "( diff:", poolNewToken1Bal-poolOldToken1Bal, ")")

		println("Trader tr01")
		println("> token0:", userOldToken0Bal, "->", userNewToken0Bal, "( diff:", userNewToken0Bal-userOldToken0Bal, ")")
		println("> token1:", userOldToken1Bal, "->", userNewToken1Bal, "( diff:", userNewToken1Bal-userOldToken1Bal, ")")
		println()
	}
}

// 6. SetFeeProtocol by Gnoswap Admin
func TestSetFeeProtocol(t *testing.T) {
	// non admin call
	std.TestSetOrigCaller(lp01)
	shouldPanic(t, func() { SetFeeProtocol(2, 2) })

	// admin call
	std.TestSetOrigCaller(gsa)
	SetFeeProtocol(6, 8)

	for _, pool := range pools {
		shouldEQ(t, pool.GetSlot0().feeProtocol, bigint(134))
	}
}

// 7. CollectProtocol by Gnoswap Admin
func TestCollectProtocol(t *testing.T) {
	std.TestSetOrigCaller(gsa)

	SetFeeProtocol(6, 8)
	pool := GetPool(pToken0, pToken1, pFee)
	test_slot0 := pool.GetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(134))

	// Make ProtocolFee via Swap by tr01 ( Mint by lp01 )
	std.TestSetOrigCaller(lp01)
	{
		println("Swap #5 - with protocol fee enabled")
		println("> direction: token0 -> token1")
		println("> amount: 200000")

		gsaOldToken0Bal := balanceOf(pool.token0, gsa)
		gsaOldToken1Bal := balanceOf(pool.token1, gsa)

		std.TestSetOrigCaller(tr01)
		Swap(pToken0, pToken1, pFee, tr01, true, 200000, MIN_SQRT_RATIO+1) // swap token0 -> token1 => fee only in token0

		// Gnoswap Admin will collect protocol fee
		std.TestSetOrigCaller(gsa)
		amount0, amount1 := CollectProtocol(pToken0, pToken1, pFee, gsa, 100000, 100000)

		gsaNewToken0Bal := balanceOf(pool.token0, gsa)
		gsaNewToken1Bal := balanceOf(pool.token1, gsa)

		println("Gnoswap Admin")
		println("> token0:", gsaOldToken0Bal, "->", gsaNewToken0Bal, "( diff:", gsaNewToken0Bal-gsaOldToken0Bal, ")")
		println("> token1:", gsaOldToken1Bal, "->", gsaNewToken1Bal, "( diff:", gsaNewToken1Bal-gsaOldToken1Bal, ")")
		println()
	}

	{
		println("Swap #6 - with protocol fee enabled")
		println("> direction: token1 -> token0")
		println("> amount: 200000")

		gsaOldToken0Bal := balanceOf(pool.token0, gsa)
		gsaOldToken1Bal := balanceOf(pool.token1, gsa)

		std.TestSetOrigCaller(tr01)
		Swap(pToken0, pToken1, pFee, tr01, false, 200000, MAX_SQRT_RATIO-1) // swap token0 -> token1 => fee only in token0

		// Gnoswap Admin will collect protocol fee
		std.TestSetOrigCaller(gsa)
		amount0, amount1 := CollectProtocol(pToken0, pToken1, pFee, gsa, 100000, 100000)

		gsaNewToken0Bal := balanceOf(pool.token0, gsa)
		gsaNewToken1Bal := balanceOf(pool.token1, gsa)

		println("Gnoswap Admin")
		println("> token0:", gsaOldToken0Bal, "->", gsaNewToken0Bal, "( diff:", gsaNewToken0Bal-gsaOldToken0Bal, ")")
		println("> token1:", gsaOldToken1Bal, "->", gsaNewToken1Bal, "( diff:", gsaNewToken1Bal-gsaOldToken1Bal, ")")
		println()
	}
}

/* GETTER_API TEST */
func TestApiGetPools(t *testing.T) {
	gpls := ApiGetPools()
	println(gpls)
}

func TestApiGetPool(t *testing.T) {
	pk := "bar_foo_500"
	gpl := ApiGetPool(pk)
	println(gpl)
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
