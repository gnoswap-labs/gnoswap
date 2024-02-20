package pool

import (
	"std"
	"testing"

	"gno.land/r/demo/consts"
)

var (
	test_tickLower       = int32(9000)
	test_tickUpper       = int32(11000)
	test_liquidityExpect = bigint(100_000_000)

	test_tickLower2 = int32(50000)
	test_tickUpper2 = int32(100000)
)

// 1. Init Pool
func TestInit(t *testing.T) {
	std.TestSetOrigCaller(test1)
	InitManual()
}

// 2. Create Foo:Bar Pool
func TestCreateFooBarPool(t *testing.T) {
	std.TestSetOrigCaller(test1)
	CreatePool(fooPath, barPath, fee500, 130621891405341611593710811006)
	shouldEQ(t, len(pools), 1)
}

// 3. Create Bar:Baz Pool
func TestCreateBarBazPool(t *testing.T) {
	std.TestSetOrigCaller(test1)
	CreatePool(barPath, bazPath, fee500, 130621891405341611593710811006)
	shouldEQ(t, len(pools), 2)
}

// 4. Mint Foo:Bar Liquidity by test1
func TestMintFooBarLiquidity(t *testing.T) {
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	Mint(
		fooPath,
		barPath,
		fee500,
		consts.POSITION_ADDR,
		-test_tickUpper,
		-test_tickLower,
		test_liquidityExpect,
	)
}

// 5. Mint Bar:Baz Liquidity by test1
func TestMintBarBazLiquidity(t *testing.T) {
	std.TestSetPrevRealm(consts.POSITION_PATH)
	std.TestSetOrigCaller(test1)

	Mint(
		barPath,
		bazPath,
		fee500,
		consts.POSITION_ADDR,
		test_tickLower,
		test_tickUpper,
		test_liquidityExpect,
	)
}

// RPC GET TESTS
var poolPath = "gno.land/r/demo/bar:gno.land/r/demo/foo:500"
var positionKey = "ZzEwd3dhNTN4Z3U0Mzk3a3Z6ejdha3hhcjkzNzB6amRwd3V4NXRoOV9fLTExMDAwX18tOTAwMA=="
var tick = int32(-11000)
var tickBitmap = int16(-5)

func TestPoolGetSlot0SqrtPriceX96(t *testing.T) {
	sqrt := PoolGetSlot0SqrtPriceX96(poolPath)
	shouldEQ(t, string(sqrt), "48055510970269007215549348797")
}

func TestPoolGetSlot0Tick(t *testing.T) {
	tick := PoolGetSlot0Tick(poolPath)
	shouldEQ(t, tick, int32(-10000))
}

func TestPoolGetSlot0FeeProtocol(t *testing.T) {
	fee := PoolGetSlot0FeeProtocol(poolPath)
	shouldEQ(t, fee, uint8(0))
}

func TestPoolGetToken0Balance(t *testing.T) {
	balance := PoolGetToken0Balance(poolPath)
	shouldEQ(t, balance, bigint(8040315))
}

func TestPoolGetToken1Balance(t *testing.T) {
	balance := PoolGetToken1Balance(poolPath)
	shouldEQ(t, balance, bigint(2958014))
}

func TestPoolGetToken0ProtocolFee(t *testing.T) {
	protocolFee := PoolGetToken0ProtocolFee(poolPath)
	shouldEQ(t, protocolFee, bigint(0))
}

func TestPoolGetToken1ProtocolFee(t *testing.T) {
	protocolFee := PoolGetToken1ProtocolFee(poolPath)
	shouldEQ(t, protocolFee, bigint(0))
}

func TestPoolGetPositionLiquidity(t *testing.T) {
	liquidity := PoolGetPositionLiquidity(poolPath, positionKey)
	shouldEQ(t, liquidity, test_liquidityExpect)
}

func TestPoolGetPositionFeeGrowthInside0LastX128(t *testing.T) {
	feeGrowth := PoolGetPositionFeeGrowthInside0LastX128(poolPath, positionKey)
	shouldEQ(t, feeGrowth, bigint(0))
}

func TestPoolGetPositionFeeGrowthInside1LastX128(t *testing.T) {
	feeGrowth := PoolGetPositionFeeGrowthInside1LastX128(poolPath, positionKey)
	shouldEQ(t, feeGrowth, bigint(0))
}

func TestPoolGetPositionTokensOwed0(t *testing.T) {
	tokensOwed := PoolGetPositionTokensOwed0(poolPath, positionKey)
	shouldEQ(t, tokensOwed, bigint(0))
}

func TestPoolGetPositionTokensOwed1(t *testing.T) {
	tokensOwed := PoolGetPositionTokensOwed1(poolPath, positionKey)
	shouldEQ(t, tokensOwed, bigint(0))
}

func TestPoolGetTickLiquidityGross(t *testing.T) {
	liquidityGross := PoolGetTickLiquidityGross(poolPath, tick)
	shouldEQ(t, liquidityGross, test_liquidityExpect)
}

func TestPoolGetTickLiquidityNet(t *testing.T) {
	liquidityNet := PoolGetTickLiquidityNet(poolPath, tick)
	shouldEQ(t, liquidityNet, test_liquidityExpect)
}

func TestPoolGetTickFeeGrowthOutside0X128(t *testing.T) {
	feeGrowth := PoolGetTickFeeGrowthOutside0X128(poolPath, tick)
	shouldEQ(t, feeGrowth, bigint(0))
}

func TestPoolGetTickFeeGrowthOutside1X128(t *testing.T) {
	feeGrowth := PoolGetTickFeeGrowthOutside1X128(poolPath, tick)
	shouldEQ(t, feeGrowth, bigint(0))
}

func TestPoolGetTickTickCumulativeOutside(t *testing.T) {
	cumulative := PoolGetTickTickCumulativeOutside(poolPath, tick)
	shouldEQ(t, cumulative, bigint(0))
}

func TestPoolGetTickSecondsPerLiquidityOutsideX128(t *testing.T) {
	seconds := PoolGetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
	shouldEQ(t, seconds, bigint(0))
}

func TestPoolGetTickSecondsOutside(t *testing.T) {
	liquidityGross := PoolGetTickSecondsOutside(poolPath, tick)
	shouldEQ(t, liquidityGross, bigint(0))
}

func TestPoolGetTickInitialized(t *testing.T) {
	initialized := PoolGetTickInitialized(poolPath, tick)
	shouldEQ(t, initialized, true)
}

func TestPoolGetTickBitmap(t *testing.T) {
	bitmap := PoolGetTickBitmap(poolPath, tickBitmap)
	shouldEQ(t, string(bitmap), "1532495540865888858358347027150309183618739122183602176")
}

func TestPoolGetToken0Path(t *testing.T) {
	token0Path := PoolGetToken0Path(poolPath)
	shouldEQ(t, token0Path, barPath)
}

func TestPoolGetToken1Path(t *testing.T) {
	token1Path := PoolGetToken1Path(poolPath)
	shouldEQ(t, token1Path, fooPath)
}

func TestPoolGetFee(t *testing.T) {
	fee := PoolGetFee(poolPath)
	shouldEQ(t, fee, fee500)
}

func TestPoolGetTickSpacing(t *testing.T) {
	spacing := PoolGetTickSpacing(poolPath)
	shouldEQ(t, spacing, int32(10))
}

func TestPoolGetFeeGrowthGlobal0X128(t *testing.T) {
	feeGrowth := PoolGetFeeGrowthGlobal0X128(poolPath)
	shouldEQ(t, feeGrowth, bigint(0))
}

func TestPoolGetFeeGrowthGlobal1X128(t *testing.T) {
	feeGrowth := PoolGetFeeGrowthGlobal1X128(poolPath)
	shouldEQ(t, feeGrowth, bigint(0))
}

func TestPoolGetLiquidity(t *testing.T) {
	liquidity := PoolGetLiquidity(poolPath)
	shouldEQ(t, liquidity, test_liquidityExpect)
}
