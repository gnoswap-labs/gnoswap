package pool

import (
	"strings"

	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

// GetPool retrieves a pool instance based on the provided token paths and fee tier.
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	return mustGetPool(poolPath).Clone()
}

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// All the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}

// GetFeeAmountTickSpacing retrieves the tick spacing associated with a given fee amount.
func GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	feeStr := formatUint(fee)
	iTickSpacing, exist := feeAmountTickSpacing.Get(feeStr)
	if !exist {
		panic(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	spacing, ok := iTickSpacing.(int32)
	if !ok {
		panic("failed to cast tick spacing to int32")
	}

	return spacing
}

func GetToken0Path(poolPath string) string {
	return mustGetPool(poolPath).Token0Path()
}

func GetToken1Path(poolPath string) string {
	return mustGetPool(poolPath).Token1Path()
}

func GetFee(poolPath string) uint32 {
	return mustGetPool(poolPath).Fee()
}

func GetBalanceToken0(poolPath string) string {
	return mustGetPool(poolPath).BalanceToken0().ToString()
}

func GetBalanceToken1(poolPath string) string {
	return mustGetPool(poolPath).BalanceToken1().ToString()
}

func GetTickSpacing(poolPath string) int32 {
	return mustGetPool(poolPath).TickSpacing()
}

func GetMaxLiquidityPerTick(poolPath string) string {
	return mustGetPool(poolPath).MaxLiquidityPerTick().ToString()
}

func GetSlot0FeeProtocol(poolPath string) uint8 {
	return mustGetPool(poolPath).Slot0FeeProtocol()
}

func GetSlot0Unlocked(poolPath string) bool {
	return mustGetPool(poolPath).Slot0Unlocked()
}

func GetFeeGrowthGlobal0X128(poolPath string) string {
	return mustGetPool(poolPath).FeeGrowthGlobal0X128().ToString()
}

func GetFeeGrowthGlobal1X128(poolPath string) string {
	return mustGetPool(poolPath).FeeGrowthGlobal1X128().ToString()
}

func GetProtocolFeesToken0(poolPath string) string {
	return mustGetPool(poolPath).ProtocolFeesToken0().ToString()
}

func GetProtocolFeesToken1(poolPath string) string {
	return mustGetPool(poolPath).ProtocolFeesToken1().ToString()
}

func GetLiquidity(poolPath string) string {
	return mustGetPool(poolPath).Liquidity().ToString()
}

func GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).PositionFeeGrowthInside0LastX128(key).ToString()
}

func GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).PositionFeeGrowthInside1LastX128(key).ToString()
}

func GetPositionTokensOwed0(poolPath, key string) string {
	return mustGetPool(poolPath).PositionTokensOwed0(key).ToString()
}

func GetPositionTokensOwed1(poolPath, key string) string {
	return mustGetPool(poolPath).PositionTokensOwed1(key).ToString()
}

func GetTickLiquidityGross(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickLiquidityGross(tick).ToString()
}

func GetTickLiquidityNet(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickLiquidityNet(tick).ToString()
}

func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickFeeGrowthOutside0X128(tick).ToString()
}

func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickFeeGrowthOutside1X128(tick).ToString()
}

func GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return mustGetPool(poolPath).GetTickCumulativeOutside(tick)
}

func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickSecondsPerLiquidityOutsideX128(tick).ToString()
}

func GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return mustGetPool(poolPath).GetTickSecondsOutside(tick)
}

func GetTickInitialized(poolPath string, tick int32) bool {
	return mustGetPool(poolPath).GetTickInitialized(tick)
}

func GetSlot0Tick(poolPath string) int32 {
	return mustGetPool(poolPath).Slot0Tick()
}

func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return u256.Zero().Set(mustGetPool(poolPath).Slot0SqrtPriceX96())
}

func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	pool := mustGetPool(poolPath)
	return u256.Zero().Set(pool.FeeGrowthGlobal0X128()), u256.Zero().Set(pool.FeeGrowthGlobal1X128())
}

func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	pool := mustGetPool(poolPath)
	return u256.Zero().Set(pool.GetTickFeeGrowthOutside0X128(tick)), u256.Zero().Set(pool.GetTickFeeGrowthOutside1X128(tick))
}

func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	pool := mustGetPool(poolPath)
	return u256.Zero().Set(pool.PositionFeeGrowthInside0LastX128(key)), u256.Zero().Set(pool.PositionFeeGrowthInside1LastX128(key))
}

func GetPositionLiquidity(poolPath, key string) *u256.Uint {
	return u256.Zero().Set(mustGetPool(poolPath).PositionLiquidity(key))
}

func ExistsPoolPath(poolPath string) bool {
	return pools.Has(poolPath)
}

func GetTickCumulative(poolPath string, secondsAgo int64) int64 {
	pool := mustGetPool(poolPath)
	return pool.Observation().TickCumulative()
}
