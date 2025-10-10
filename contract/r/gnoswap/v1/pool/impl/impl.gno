package impl

import (
	"chain/runtime"

	u256 "gno.land/p/gnoswap/uint256"
	pool "gno.land/r/gnoswap/v1/pool"
)

// PoolImpl wraps the v1 pool contract to implement the Pool interface.
// This allows the pool to be used with the upgradeable proxy pattern.
type PoolImpl struct{}

var poolImpl *PoolImpl = &PoolImpl{}
var gRealm = runtime.CurrentRealm()

// GetInstance returns the pool implementation instance.
// Only accessible from the loader package.
func GetInstance() *PoolImpl {
	caller := runtime.PreviousRealm().PkgPath()
	if caller != "gno.land/r/gnoswap/v1/pool/loader" {
		panic("not allowed: only loader can get instance")
	}

	return poolImpl
}

// CreatePool creates a new concentrated liquidity pool.
func (p *PoolImpl) CreatePool(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	pool.CreatePool(cross, token0Path, token1Path, fee, sqrtPriceX96)
}

// Mint adds liquidity to a pool position.
func (p *PoolImpl) Mint(
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

// Burn removes liquidity from a position.
func (p *PoolImpl) Burn(
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

// Collect transfers owed tokens from a position to recipient.
func (p *PoolImpl) Collect(
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

// CollectProtocol collects accumulated protocol fees.
func (p *PoolImpl) CollectProtocol(
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

// Swap executes a token swap.
func (p *PoolImpl) Swap(
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

// DrySwap simulates a swap without executing it.
func (p *PoolImpl) DrySwap(
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

// SetFeeProtocol sets the protocol fee percentage.
func (p *PoolImpl) SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	pool.SetFeeProtocol(cross, feeProtocol0, feeProtocol1)
}

// GetPoolPath returns the pool path for given tokens and fee.
func (p *PoolImpl) GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return pool.GetPoolPath(token0Path, token1Path, fee)
}

// GetSlot0SqrtPriceX96 returns the current sqrt price.
func (p *PoolImpl) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return pool.GetSlot0SqrtPriceX96(poolPath)
}

// GetSlot0Tick returns the current tick.
func (p *PoolImpl) GetSlot0Tick(poolPath string) int32 {
	return pool.GetSlot0Tick(poolPath)
}

// GetLiquidity returns current liquidity.
func (p *PoolImpl) GetLiquidity(poolPath string) string {
	return pool.GetLiquidity(poolPath)
}

// GetBalanceToken0 returns token0 balance.
func (p *PoolImpl) GetBalanceToken0(poolPath string) string {
	return pool.GetBalanceToken0(poolPath)
}

// GetBalanceToken1 returns token1 balance.
func (p *PoolImpl) GetBalanceToken1(poolPath string) string {
	return pool.GetBalanceToken1(poolPath)
}

// GetFeeGrowthGlobalX128 returns global fee growth values.
func (p *PoolImpl) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return pool.GetFeeGrowthGlobalX128(poolPath)
}

// GetPositionFeeGrowthInsideLastX128 returns position fee growth.
func (p *PoolImpl) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return pool.GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

// GetObservation returns oracle observation data.
func (p *PoolImpl) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	return pool.GetObservation(poolPath, secondsAgo)
}

// ExistsPoolPath checks if pool exists.
func (p *PoolImpl) ExistsPoolPath(poolPath string) bool {
	return pool.ExistsPoolPath(poolPath)
}

// ApiGetPool returns pool data as JSON.
func (p *PoolImpl) ApiGetPool(poolPath string) string {
	return pool.ApiGetPool(poolPath)
}

// ApiGetTWAP returns time-weighted average price.
func (p *PoolImpl) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return pool.ApiGetTWAP(poolPath, secondsAgo)
}
