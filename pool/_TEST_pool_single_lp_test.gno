package pool

import (
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	"std"
	"testing"

========
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
	"encoding/gjson"
	"std"
	"strconv"
	"testing"

	"gno.land/r/demo/consts"

<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	"gno.land/p/demo/u256"
========
	u256 "gno.land/p/big/uint256"
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
)

var (
	test_tickLower          = int32(9000)
	test_tickUpper          = int32(11000)
	test_liquidityExpectStr = "1000"
	test_liquidityExpect256 = u256.NewUint(1000)

	test_tickLower2 = int32(50000)
	test_tickUpper2 = int32(100000)
)

// 1. Init & Create Pool using Factory Contract by Gnoswap Admin
func TestInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)
	InitManual()

<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	std.TestSetOrigCaller(test1)
	CreatePool(barPath, fooPath, fee500, 130621891405341611593710811006)

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { CreatePool(barPath, fooPath, 500, 130621891405341611593710811006) })
========
	std.TestSetPrevAddr(test1)
	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)
	CreatePool(barPath, fooPath, fee500, "130621891405341611593710811006") // x2.7
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
}

// 2. Mint by test1
func TestMint(t *testing.T) {
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
========
	std.TestSetPrevAddr(test1)

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	Mint(
		fooPath,
		barPath,
		fee500,
		consts.POSITION_ADDR,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpectStr,
	)
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK

	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect)), true)
========
	shouldEQ(t, amount0, "29")
	shouldEQ(t, amount1, "80")

	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity.Dec(), test_liquidityExpectStr)
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)

	m81, m82 := Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	m101, m102 := Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)

	shouldNEQ(t, m81, "0")
	shouldNEQ(t, m82, "0")
	shouldEQ(t, m81, m101)
	shouldEQ(t, m82, m102)

	test_liquidity = pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect*10)), true)
========
	shouldEQ(t, true, test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))))
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	// tickLower > currentTick == don't add to current liquidity
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower2, test_tickUpper2, test_liquidityExpectStr)

	// tickUpper < current tick == don't add to current liquidity
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, -test_tickUpper2, -test_tickLower2, test_liquidityExpectStr)

	// tickUpper < tickLower == don't add to current liquidity
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, -test_tickUpper, -test_tickLower, test_liquidityExpectStr)

	// test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, true, test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))))

	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpectStr)

	test_liquidity = pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect*10)), true)

	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, test_liquidityExpect)

	test_liquidity = pool.PoolGetLiquidity()
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect*20)), true)
========
	shouldEQ(t, true, test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(20))))

>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
}

// 3. Burn by test1
func TestBurn(t *testing.T) {
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	b11, b12 := Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	b21, b22 := Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpectStr)
	shouldEQ(t, b11, b21)
	shouldEQ(t, b12, b22)

	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect*18)), true)
========
	shouldEQ(t, true, test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(18))))
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(8)).ToString())
	test_liquidity = pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect*10)), true)
========
	shouldEQ(t, true, test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(10))))
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, "1")
	test_liquidity = pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(9999)), true)
========
	shouldEQ(t, test_liquidity.ToString(), "9999")
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, "999")
	test_liquidity = pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.Eq(u256.FromBigint(test_liquidityExpect*9)), true)
========
	shouldEQ(t, true, test_liquidity.Eq(new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(9))))
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(9)).ToString())
	test_liquidity = pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.IsZero(), true)
========
	shouldEQ(t, test_liquidity.ToString(), "0")
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
}

// 4. Collect
func TestCollect(t *testing.T) {
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	// withdraw all token before test `Collect`
	Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "50000000", "50000000")

	// pool should have zero liquidity
	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.IsZero(), true)
========
	shouldEQ(t, test_liquidity.ToString(), "0")
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	c11, c12 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "50000000", "50000000")

	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	c21, c22 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "50000000", "50000000")

	shouldEQ(t, c11, c21) // 443
	shouldEQ(t, c12, c22) // 1206

	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	c31, c32 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "100", "100")
	shouldEQ(t, c31, "100")
	shouldEQ(t, c32, "100")

	c41, c42 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "50000000", "50000000")
	shouldEQ(t, c41, "343")  // 343 = c21 - 100
	shouldEQ(t, c42, "1106") // 1106 = c22 - 100

	// Mint > No Burn => nothing to collect
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	// Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, test_liquidityExpectStr*15)
	c51, c52 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "50000000", "50000000")
	shouldEQ(t, c51, "0")
	shouldEQ(t, c52, "0")

	// Burn Now => something to collect
	Burn(barPath, fooPath, fee500, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(15)).ToString())
	c61, c62 := Collect(barPath, fooPath, fee500, test1, test_tickLower, test_tickUpper, "50000000", "50000000")
	shouldNEQ(t, c61, "0")
	shouldNEQ(t, c62, "0")
}

// 5. Swap by test1
func TestSwap(t *testing.T) {
	pool := GetPool(barPath, fooPath, fee500)
	test_liquidity := pool.PoolGetLiquidity()
<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, test_liquidity.IsZero(), true)
========
	shouldEQ(t, test_liquidity.ToString(), "0")
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)
	Mint(barPath, fooPath, fee500, consts.POSITION_ADDR, test_tickLower, test_tickUpper, new(u256.Uint).Mul(test_liquidityExpect256, u256.NewUint(20000)).ToString())

	// Swap several times
	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	test_price := consts.MIN_PRICE
	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(
			fooPath,             // token0Path
			barPath,             // token1Path
			fee500,              // fee
			test1,               // recipient
			true,                // zeroForOne
			"10000",             // _amountSpecified
			test_price,          // _sqrtPriceLimitX96
			std.GetOrigCaller(), // payer
		)
		shouldNEQ(t, amount0, "0")
		shouldNEQ(t, amount1, "0")
		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(intAmount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-intAmount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(intAmount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-intAmount1))
	}

	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(barPath, fooPath, fee500, test1, true, "5000", test_price, std.GetOrigCaller()) // give enough amount to take fees away
		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(intAmount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-intAmount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(intAmount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-intAmount1))
	}

	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(barPath, fooPath, fee500, test1, true, "1000", test_price, std.GetOrigCaller()) // give enough amount to take fees away
		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(intAmount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-intAmount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(intAmount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-intAmount1))
	}

	// Swap token1 -> token0
	{
		poolOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userOldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userOldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		amount0, amount1 := Swap(barPath, fooPath, fee500, test1, false, "16000", consts.MAX_PRICE, std.GetOrigCaller()) // give enough amount to take fees away
		intAmount0, _ := strconv.Atoi(amount0)
		intAmount1, _ := strconv.Atoi(amount1)

		poolNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, consts.POOL_ADDR)
		poolNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, consts.POOL_ADDR)

		userNewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		userNewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		shouldEQ(t, userOldToken0Bal-userNewToken0Bal, int64(intAmount0))
		shouldEQ(t, userNewToken1Bal-userOldToken1Bal, int64(-intAmount1))
		shouldEQ(t, poolNewToken0Bal-poolOldToken0Bal, int64(intAmount0))
		shouldEQ(t, poolOldToken1Bal-poolNewToken1Bal, int64(-intAmount1))
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
		shouldEQ(t, pool.PoolGetSlot0().feeProtocol, 134)
	}
}

// 7. CollectProtocol by Gnoswap Admin
func TestCollectProtocol(t *testing.T) {
	std.TestSetOrigCaller(test1)

	SetFeeProtocol(6, 8)
	pool := GetPool(barPath, fooPath, fee500)
	test_slot0 := pool.PoolGetSlot0()
	shouldEQ(t, test_slot0.feeProtocol, 134)

	// Make ProtocolFee via Swap by test1 ( Mint by test1 )
	std.TestSetOrigCaller(test1)
	{

		std.TestSetPrevRealm(consts.ROUTER_PATH)
		std.TestSetOrigCaller(test1)
		Swap(barPath, fooPath, fee500, test1, true, "200000", consts.MIN_PRICE, std.GetOrigCaller()) // swap token0 -> token1 => fee only in token0

		test1OldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1OldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
		std.TestSetPrevAddr(test1)
		amount0, amount1 := CollectProtocol(barPath, fooPath, fee500, test1, u256.NewUint(100000), u256.NewUint(100000))
========
		std.TestSetPrevAddr(gsa)
		amount0, amount1 := CollectProtocol(barPath, fooPath, fee500, test1, "100000", "100000")
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

		test1NewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1NewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		_token0Diff := test1NewToken0Bal - test1OldToken0Bal
		_token1Diff := test1NewToken1Bal - test1OldToken1Bal

<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	{
		std.TestSetPrevRealm(consts.ROUTER_PATH)
		std.TestSetOrigCaller(test1)
		Swap(barPath, fooPath, fee500, test1, false, 200000, consts.MAX_SQRT_RATIO-1, std.GetOrigCaller()) // swap token0 -> token1 => fee only in token0

		test1OldToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1OldToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)

		std.TestSetPrevAddr(test1)
		amount0, amount1 := CollectProtocol(barPath, fooPath, fee500, test1, u256.NewUint(100000), u256.NewUint(100000))

		test1NewToken0Bal := balanceOfByRegisterCall(pool.token0Path, test1)
		test1NewToken1Bal := balanceOfByRegisterCall(pool.token1Path, test1)
========
		token0DiffStr := strconv.Itoa(int(_token0Diff))
		token1DiffStr := strconv.Itoa(int(_token1Diff))

		shouldEQ(t, token0DiffStr, amount0)
		shouldEQ(t, token1DiffStr, amount1)
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno
	}
}

/* GETTER_API TEST */
func TestApiGetPools(t *testing.T) {
	gpls := ApiGetPools()
	jsonStr := gjson.Parse(gpls)

<<<<<<<< HEAD:pool/_TEST_pool_single_lp_test.gno_OK
	shouldEQ(t, jsonStr.Get("stat.height").Int(), GetHeight())
	shouldEQ(t, jsonStr.Get("stat.timestamp").Int(), GetTimestamp())
========
	// shouldEQ(t, jsonStr.Get("stat.height").Int(), std.GetHeight())
	// shouldEQ(t, jsonStr.Get("stat.timestamp").Int(), time.Now().Unix())
>>>>>>>> 486effd (feat: uint256, int256 instead of bigint):pool/_TEST_pool_single_lp_test.gno

	// shouldEQ(t, len(jsonStr.Get("response").Array()), 1)
}
