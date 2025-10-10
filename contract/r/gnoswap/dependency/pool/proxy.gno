package pool

import (
	"chain/runtime"

	u256 "gno.land/p/gnoswap/uint256"
)

// pool is the actual pool implementation, having all the needed business logic.
var pool Pool

// allowedImpls contains realms that can be used to update the actual pool implementation.
// This is like that to be able to rollback using a previous pool implementation in case
// the latest implementation has a breaking bug. After a test period, a proposal can be
// executed to remove all previous pool implementations and leave the last one.
var allowedImpls []string

// CreatePool proxies to the current pool implementation.
func CreatePool(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	pool.CreatePool(cross, token0Path, token1Path, fee, sqrtPriceX96)
}

// Mint proxies to the current pool implementation.
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
	return pool.Mint(cross, token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
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
	return pool.Burn(cross, token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
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
	return pool.Collect(cross, token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
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
	return pool.CollectProtocol(cross, token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
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
	return pool.Swap(cross, token0Path, token1Path, fee, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, caller)
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
	return pool.DrySwap(cross, token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96)
}

// SetFeeProtocol proxies to the current pool implementation.
func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	pool.SetFeeProtocol(cross, feeProtocol0, feeProtocol1)
}

// GetPoolPath proxies to the current pool implementation.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return pool.GetPoolPath(token0Path, token1Path, fee)
}

// GetSlot0SqrtPriceX96 proxies to the current pool implementation.
func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return pool.GetSlot0SqrtPriceX96(poolPath)
}

// GetSlot0Tick proxies to the current pool implementation.
func GetSlot0Tick(poolPath string) int32 {
	return pool.GetSlot0Tick(poolPath)
}

// GetLiquidity proxies to the current pool implementation.
func GetLiquidity(poolPath string) string {
	return pool.GetLiquidity(poolPath)
}

// GetBalanceToken0 proxies to the current pool implementation.
func GetBalanceToken0(poolPath string) string {
	return pool.GetBalanceToken0(poolPath)
}

// GetBalanceToken1 proxies to the current pool implementation.
func GetBalanceToken1(poolPath string) string {
	return pool.GetBalanceToken1(poolPath)
}

// GetFeeGrowthGlobalX128 proxies to the current pool implementation.
func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return pool.GetFeeGrowthGlobalX128(poolPath)
}

// GetPositionFeeGrowthInsideLastX128 proxies to the current pool implementation.
func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return pool.GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

// GetObservation proxies to the current pool implementation.
func GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	return pool.GetObservation(poolPath, secondsAgo)
}

// ExistsPoolPath proxies to the current pool implementation.
func ExistsPoolPath(poolPath string) bool {
	return pool.ExistsPoolPath(poolPath)
}

// ApiGetPool proxies to the current pool implementation.
func ApiGetPool(poolPath string) string {
	return pool.ApiGetPool(poolPath)
}

// ApiGetTWAP proxies to the current pool implementation.
func ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return pool.ApiGetTWAP(poolPath, secondsAgo)
}

// UpdateImpl updates the current pool implementation.
// This method is intended to be used on a proposal or by admin.
// AllowedImpls are a list of realms that can call this method,
// in case the new pool implementation had a breaking bug.
// Any value set as nil will be ignored.
func UpdateImpl(cur realm, r UpdateRequest) {
	gRealm := runtime.PreviousRealm().PkgPath()

	if !InAllowedImpls(gRealm) {
		panic("permission denied for prev realm: " + gRealm)
	}

	if r.AllowedImpls != nil {
		allowedImpls = r.AllowedImpls
	}

	if r.Pool != nil {
		pool = r.Pool
	}
}

// AllowedImpls returns a copy of the allowed implementations list.
func AllowedImpls() []string {
	dup := make([]string, len(allowedImpls))
	copy(dup, allowedImpls)
	return dup
}

// InAllowedImpls checks if a package is in the allowed implementations list.
func InAllowedImpls(pkg string) bool {
	if len(allowedImpls) == 0 {
		return true // corner case for initialization
	}
	for _, d := range allowedImpls {
		if pkg == d {
			return true
		}
	}
	return false
}
