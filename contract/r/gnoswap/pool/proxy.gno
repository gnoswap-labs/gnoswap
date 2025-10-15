package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// CreatePool proxies to the current pool implementation.
// This function provides a stable public API that routes calls to the active implementation.
// When the implementation is upgraded, this function automatically routes to the new version
// without requiring any changes to external callers.
func CreatePool(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	getImpl().CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}

// Mint proxies to the current pool implementation.
// Routes position minting calls to the active implementation.
func Mint(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	return getImpl().Mint(token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

// Burn proxies to the current pool implementation.
func Burn(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	return getImpl().Burn(token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

// Collect proxies to the current pool implementation.
func Collect(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	return getImpl().Collect(token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

// CollectProtocol proxies to the current pool implementation.
func CollectProtocol(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	return getImpl().CollectProtocol(token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
}

// Swap proxies to the current pool implementation.
func Swap(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	caller address,
) (string, string) {
	return getImpl().Swap(token0Path, token1Path, fee, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, caller)
}

// DrySwap proxies to the current pool implementation.
func DrySwap(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (string, string) {
	return getImpl().DrySwap(token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96)
}

// SetFeeProtocol proxies to the current pool implementation.
func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	getImpl().SetFeeProtocol(feeProtocol0, feeProtocol1)
}

// GetPoolPath proxies to the current pool implementation.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return getImpl().GetPoolPath(token0Path, token1Path, fee)
}

// GetSlot0SqrtPriceX96 proxies to the current pool implementation.
func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return getImpl().GetSlot0SqrtPriceX96(poolPath)
}

// GetSlot0Tick proxies to the current pool implementation.
func GetSlot0Tick(poolPath string) int32 {
	return getImpl().GetSlot0Tick(poolPath)
}

// GetLiquidity proxies to the current pool implementation.
func GetLiquidity(poolPath string) string {
	return getImpl().GetLiquidity(poolPath)
}

// GetBalanceToken0 proxies to the current pool implementation.
func GetBalanceToken0(poolPath string) string {
	return getImpl().GetBalanceToken0(poolPath)
}

// GetBalanceToken1 proxies to the current pool implementation.
func GetBalanceToken1(poolPath string) string {
	return getImpl().GetBalanceToken1(poolPath)
}

// GetFeeGrowthGlobalX128 proxies to the current pool implementation.
func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return getImpl().GetFeeGrowthGlobalX128(poolPath)
}

// GetPositionFeeGrowthInsideLastX128 proxies to the current pool implementation.
func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return getImpl().GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

// GetObservation proxies to the current pool implementation.
func GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	return getImpl().GetObservation(poolPath, secondsAgo)
}

// ExistsPoolPath proxies to the current pool implementation.
func ExistsPoolPath(poolPath string) bool {
	return getImpl().ExistsPoolPath(poolPath)
}

// ApiGetPool proxies to the current pool implementation.
func ApiGetPool(poolPath string) string {
	return getImpl().ApiGetPool(poolPath)
}

// ApiGetTWAP proxies to the current pool implementation.
func ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return getImpl().ApiGetTWAP(poolPath, secondsAgo)
}

// getImpl returns the currently active pool implementation.
// This function is used by all proxy functions to route calls to the active implementation.
// If no implementation is set, it panics to prevent invalid state.
func getImpl() IPool {
	if poolImpl == nil {
		panic("pool implementation is not set")
	}

	return poolImpl
}
