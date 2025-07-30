package pool

import (
	"strings"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

// GetPool retrieves a pool instance based on the provided token paths and fee tier.
//
// This function determines the pool path by combining the paths of token0 and token1 along with the fee tier,
// and then retrieves the corresponding pool instance using that path.
//
// Parameters:
// - token0Path (string): The unique path for token0.
// - token1Path (string): The unique path for token1.
// - fee (uint32): The fee tier for the pool, expressed in basis points (e.g., 3000 for 0.3%).
//
// Returns:
// - *Pool: A pointer to the Pool instance corresponding to the provided tokens and fee tier.
//
// Notes:
// - The order of token paths (token0Path and token1Path) matters and should match the pool's configuration.
// - Ensure that the tokens and fee tier provided are valid and registered in the system.
//
// Example:
// pool := GetPool("gno.land/r/demo/wugnot", "gno.land/r/gnoswap/v1/gns", 3000)
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	return mustGetPool(poolPath).Clone()
}

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
//
// This function ensures that the token paths are registered and sorted in alphabetical order
// before combining them with the fee tier to create a unique identifier for the pool.
//
// Parameters:
// - token0Path (string): The unique identifier or path for token0.
// - token1Path (string): The unique identifier or path for token1.
// - fee (uint32): The fee tier for the pool, expressed in basis points (e.g., 3000 for 0.3%).
//
// Returns:
// - string: A unique pool path string in the format "token0Path:token1Path:fee".
//
// Notes:
//   - The function validates that both `token0Path` and `token1Path` are registered in the system
//     using `common.MustRegistered`.
//   - The token paths are sorted alphabetically to ensure consistent pool path generation, regardless
//     of the input order.
//   - This sorting guarantees that the pool path remains deterministic for the same pair of tokens and fee.
//
// Example:
// poolPath := GetPoolPath("path/to/token0", "path/to/token1", 3000)
// // Output: "path/to/token0:path/to/token1:3000"
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// all the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}

// GetFeeAmountTickSpacing retrieves the tick spacing associated with a given fee amount.
// The tick spacing determines the minimum distance between ticks in the pool.
//
// Parameters:
//   - fee (uint32): The fee tier in basis points (e.g., 3000 for 0.3%)
//
// Returns:
//   - int32: The tick spacing value for the given fee tier
//
// Panics:
//   - If the fee amount is not registered in feeAmountTickSpacing
func GetFeeAmountTickSpacing(fee uint32) int32 {
	feeStr := formatUint(fee)
	iTickSpacing, exist := feeAmountTickSpacing.Get(feeStr)
	if !exist {
		panic(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	return iTickSpacing.(int32)
}

func GetPoolList() []string {
	poolPaths := []string{}
	pools.Iterate("", "", func(poolPath string, _ any) bool {
		poolPaths = append(poolPaths, poolPath)

		return false
	})

	return poolPaths
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