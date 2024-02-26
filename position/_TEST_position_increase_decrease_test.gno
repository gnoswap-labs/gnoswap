package position

import (
	"std"
	"testing"

	"gno.land/p/demo/common"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"
)

// 1. Init & Create Pool
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(test1)
	pl.InitManual()

	std.TestSetOrigCaller(test1)
	pl.CreatePool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(10000)) // x2.71814592682522526700950038502924144268035888671875

	// sqrtPrice
	shouldPanic(t, func() { pl.CreatePool(fooPath, barPath, fee500, common.TickMathGetSqrtRatioAtTick(10000)) })
}

func TestMintPosition(t *testing.T) {
	std.TestSetOrigCaller(test1)

	tokenId, liquidity, amount0, amount1 := Mint(
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		bigint(50_000_000),
		bigint(50_000_000),
		bigint(0),
		bigint(0),
		max_timeout,
	)
	shouldEQ(t, tokenId, 1)
	shouldEQ(t, getNextId(), 2)
	shouldEQ(t, amount0, bigint(18394891))
	shouldEQ(t, amount1, bigint(50000000))
}

func TestIncreaseLiquidity(t *testing.T) {
	std.TestSetOrigCaller(test1)

	pool := getPoolFromLpTokenId(uint64(1))
	oldLiquidity := pool.PoolGetLiquidity()

	IncreaseLiquidity(
		uint64(1),          // tokenId
		bigint(10_000_000), // amount0Desired
		bigint(10_000_000), // amount1Desired
		bigint(0),          // amount0Min
		bigint(0),          // amount1Min
		max_timeout,        // deadline
	)

	newLiquidity := pool.PoolGetLiquidity()

	shouldGT(t, oldLiquidity, newLiquidity)
}

func TestCollectFeeBeforeSwap(t *testing.T) {
	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, bigint(0))
	shouldEQ(t, fee1, bigint(0))
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

func TestSwap(t *testing.T) {
	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	amount0, amount1 := pl.Swap(
		barPath,
		fooPath,
		fee500,
		test1,
		true,
		bigint(1_234_567),
		consts.MIN_PRICE,
		test1,
	)
}

func TestCollectFeeAfterSwap(t *testing.T) {
	std.TestSetPrevRealm("")
	std.TestSetOrigCaller(test1)

	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, bigint(611)) // this is input token
	shouldEQ(t, fee1, bigint(0))   // this it output token
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
}

func TestCollectFee2(t *testing.T) {
	std.TestSetPrevRealm("")
	std.TestSetOrigCaller(test1)

	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, bigint(0)) // this is input token
	shouldEQ(t, fee1, bigint(0)) // this it output token
	shouldEQ(t, poolPath, "gno.land/r/demo/bar:gno.land/r/demo/foo:500")

	// println(unclaimedFee(uint64(1))) // should be 0, 0
}

func TestSwap2(t *testing.T) {
	std.TestSetPrevRealm(consts.ROUTER_PATH)
	std.TestSetOrigCaller(test1)
	amount0, amount1 := pl.Swap(
		barPath,
		fooPath,
		fee500,
		test1,
		true,
		bigint(1_000_000),
		consts.MIN_PRICE,
		test1,
	)

	// UNCLAIMED_FEE
	std.TestSetPrevRealm("")
	std.TestSetOrigCaller(test1)

	// println(unclaimedFee(uint64(1))) // 499 0
	// tokenId, fee0, fee1, poolPath := CollectFee(1)
	// println("fee0", fee0) // 495 ( 1% of fee differ )
	// println("fee1", fee1) // 0
}

func TestDecreaseLiquidity(t *testing.T) {
	std.TestSetPrevRealm("")
	std.TestSetOrigCaller(test1)

	oldLiquidity := getPoolFromLpTokenId(uint64(1)).PoolGetLiquidity()

	tokenId, liquidity, amount0, amount1 := DecreaseLiquidity(
		uint64(1),          // tokenId
		bigint(10_000_000), // liquidity
		bigint(0),          // amount0Min
		bigint(0),          // amount1Min
		max_timeout,        // deadline
	)

	newLiquidity := getPoolFromLpTokenId(uint64(1)).PoolGetLiquidity()
	shouldLT(t, oldLiquidity, newLiquidity)

	// check fee left
	tokenId, fee0, fee1, poolPath := CollectFee(1)
	shouldEQ(t, tokenId, uint64(1))
	shouldEQ(t, fee0, bigint(0))
	shouldEQ(t, fee1, bigint(0))
}
