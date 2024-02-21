package pool

import (
	"encoding/gjson"
	"std"
	"testing"

	"gno.land/r/demo/consts"

	_ "gno.land/r/demo/grc20_wrapper"
)

var (
	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(1000)

	test_tickLower2 = int32(50000)
	test_tickUpper2 = int32(100000)
)

// 1. Init & Create Pool using Factory Contract by Gnoswap Admin
func TestInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)
	InitManual()

	std.TestSetOrigCaller(test1)
	CreatePool(barPath, fooPath, fee500, 130621891405341611593710811006)

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { CreatePool(barPath, fooPath, 500, 130621891405341611593710811006) })
}

// 2. Mint by test1
func TestMint(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/demo/position")
	std.TestSetOrigCaller(test1)

	Mint(
		fooPath,
		barPath,
		fee500,
		posAddr,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpect,
	)

	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect)

	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)

	m81, m82 := Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	m101, m102 := Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)

	shouldNEQ(t, m81, bigint(0))
	shouldNEQ(t, m82, bigint(0))
	shouldEQ(t, m81, m101)
	shouldEQ(t, m82, m102)

	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	// tickLower > currentTick == don't add to current liquidity
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower2, test_tickUpper2, test_liquidityExpect)

	// tickUpper < current tick == don't add to current liquidity
	Mint(barPath, fooPath, fee500, posAddr, -test_tickUpper2, -test_tickLower2, test_liquidityExpect)

	// tickUpper < tickLower == don't add to current liquidity
	Mint(barPath, fooPath, fee500, posAddr, -test_tickUpper, -test_tickLower, test_liquidityExpect)

	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect)

	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*20)
}

// 3. Burn by test1
func TestBurn(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/demo/position")
	std.TestSetOrigCaller(test1)

	b11, b12 := Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect)
	b21, b22 := Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect)
	shouldEQ(t, b11, b21)
	shouldEQ(t, b12, b22)

	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*18)

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*8)
	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*10)

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, 1)
	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, bigint(9999))

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, 999)
	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, test_liquidityExpect*9)

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*9)
	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	// can't burn when liq is 0
	// Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect)
	shouldPanic(t, func() { Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect) })
}

// 4. Collect
func TestCollect(t *testing.T) {
	std.TestSetPrevRealm("gno.land/r/demo/position")
	std.TestSetOrigCaller(test1)

	// withdraw all token before test `Collect`
	Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 50000000, 50000000)

	// pool should have zero liquidity
	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c11, c12 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 50000000, 50000000)

	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c21, c22 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 50000000, 50000000)

	shouldEQ(t, c11, c21)
	shouldEQ(t, c12, c22)

	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c31, c32 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 100, 100)
	shouldEQ(t, c31, bigint(100))
	shouldEQ(t, c32, bigint(100))

	c41, c42 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c41, c21-bigint(100))
	shouldEQ(t, c42, c22-bigint(100))

	// Mint > No Burn => nothing to collect
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	// Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c51, c52 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldEQ(t, c51, bigint(0))
	shouldEQ(t, c52, bigint(0))

	// Burn Now => something to collect
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpect*15)
	c61, c62 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, 50000000, 50000000)
	shouldNEQ(t, c61, bigint(0))
	shouldNEQ(t, c62, bigint(0))
}

// 5. Swap by test1
func TestSwap(t *testing.T) {
	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity, bigint(0))

	std.TestSetPrevRealm("gno.land/r/demo/position")
	std.TestSetOrigCaller(test1)
	Mint(barPath, fooPath, fee500, posAddr, test_tickLower, test_tickUpper, test_liquidityExpect*20000)

	// Swap several times
	std.TestSetPrevRealm("gno.land/r/demo/router")
	std.TestSetOrigCaller(test1)
	test_price := bigint(consts.MIN_PRICE)
	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(
			fooPath,
			barPath,
			fee500,
			test1,
			true,
			bigint(10000),
			test_price,
			std.GetOrigCaller(),
		)

		shouldNEQ(t, amount0, bigint(0))
		shouldNEQ(t, amount1, bigint(0))

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(amount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-amount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(amount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-amount1))
	}

	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(barPath, fooPath, fee500, test1, true, 5000, test_price, std.GetOrigCaller()) // give enough amount to take fees away

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(amount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-amount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(amount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-amount1))
	}

	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(barPath, fooPath, fee500, test1, true, 1000, test_price, std.GetOrigCaller()) // give enough amount to take fees away

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(amount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-amount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(amount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-amount1))
	}

	// Swap token1 -> token0
	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(barPath, fooPath, fee500, test1, false, 16000, consts.MAX_PRICE, std.GetOrigCaller()) // give enough amount to take fees away

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, poolAddr)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, poolAddr)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(amount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-amount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(amount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-amount1))
	}
}

// 6. SetFeeProtocol by Gnoswap Admin
func TestSetFeeProtocol(t *testing.T) {
	// non admin call
	std.TestSetOrigCaller(test1)
	shouldPanic(t, func() { SetFeeProtocol(2, 2) })

	// admin call
	std.TestSetOrigCaller(test1)
	SetFeeProtocol(6, 8)

	for _, pool := range pools {
		shouldEQ(t, pool.PoolGetSlot0().feeProtocol, bigint(134))
	}
}

// 7. CollectProtocol by Gnoswap Admin
func TestCollectProtocol(t *testing.T) {
	std.TestSetOrigCaller(test1)

	SetFeeProtocol(6, 8)
	pool := GetPool(barPath, fooPath, fee500)
	test_slot0 := pool.PoolGetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, bigint(134))

	// Make ProtocolFee via Swap by test1 ( Mint by test1 )
	std.TestSetOrigCaller(test1)
	{

		std.TestSetPrevRealm("gno.land/r/demo/router")
		std.TestSetOrigCaller(test1)
		Swap(barPath, fooPath, fee500, test1, true, 200000, consts.MIN_PRICE, std.GetOrigCaller()) // swap token0 -> token1 => fee only in token0

		test1OldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1OldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		std.TestSetPrevAddr(test1)
		amount0, amount1 := CollectProtocol(barPath, fooPath, fee500, test1, 100000, 100000)

		test1NewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1NewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, test1NewToken0Bal-test1OldToken0Bal, int64(amount0))
		shouldEQ(t, test1NewToken1Bal-test1OldToken1Bal, int64(amount1))
	}

	{

		std.TestSetPrevRealm("gno.land/r/demo/router")
		std.TestSetOrigCaller(test1)
		Swap(barPath, fooPath, fee500, test1, false, 200000, MAX_SQRT_RATIO-1, std.GetOrigCaller()) // swap token0 -> token1 => fee only in token0

		test1OldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1OldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		std.TestSetPrevAddr(test1)
		amount0, amount1 := CollectProtocol(barPath, fooPath, fee500, test1, 100000, 100000)

		test1NewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1NewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)
	}
}

/* GETTER_API TEST */
func TestApiGetPools(t *testing.T) {
	gpls := ApiGetPools()
	jsonStr := gjson.Parse(gpls)

	shouldEQ(t, jsonStr.Get("stat.height").Int(), GetHeight())
	shouldEQ(t, jsonStr.Get("stat.timestamp").Int(), GetTimestamp())

	shouldEQ(t, len(jsonStr.Get("response").Array()), 1)
}

func TestApiGetPool(t *testing.T) {
	gpl := ApiGetPool("gno.land/r/demo/bar:gno.land/r/demo/foo:500")
	jsonStr := gjson.Parse(gpl)

	shouldEQ(t, jsonStr.Get("stat.height").Int(), GetHeight())
	shouldEQ(t, jsonStr.Get("stat.timestamp").Int(), GetTimestamp())

	shouldEQ(t, len(jsonStr.Get("response.positions").Array()), 4)
}
