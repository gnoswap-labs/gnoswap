package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// Pool interface defines all public methods that must be implemented by pool contract versions.
// This allows for upgradeable pool implementations while maintaining backwards compatibility.
type Pool interface {
	// CreatePool creates a new concentrated liquidity pool.
	CreatePool(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		sqrtPriceX96 string,
	)

	// Mint adds liquidity to a pool position.
	Mint(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		liquidityAmount string,
		positionCaller address,
	) (string, string)

	// Burn removes liquidity from a position.
	Burn(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		liquidityAmount string,
		positionCaller address,
	) (string, string)

	// Collect transfers owed tokens from a position to recipient.
	Collect(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		tickLower int32,
		tickUpper int32,
		amount0Requested string,
		amount1Requested string,
	) (string, string)

	// CollectProtocol collects accumulated protocol fees.
	CollectProtocol(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		amount0Requested string,
		amount1Requested string,
	) (string, string)

	// Swap executes a token swap.
	Swap(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
		caller address,
	) (string, string)

	// DrySwap simulates a swap without executing it.
	DrySwap(
		cur realm,
		token0Path string,
		token1Path string,
		fee uint32,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
	) (string, string)

	// SetFeeProtocol sets the protocol fee percentage.
	SetFeeProtocol(
		cur realm,
		feeProtocol0 uint8,
		feeProtocol1 uint8,
	)

	// GetPoolPath returns the pool path for given tokens and fee.
	GetPoolPath(token0Path, token1Path string, fee uint32) string

	// GetSlot0SqrtPriceX96 returns the current sqrt price.
	GetSlot0SqrtPriceX96(poolPath string) *u256.Uint

	// GetSlot0Tick returns the current tick.
	GetSlot0Tick(poolPath string) int32

	// GetLiquidity returns current liquidity.
	GetLiquidity(poolPath string) string

	// GetBalanceToken0 returns token0 balance.
	GetBalanceToken0(poolPath string) string

	// GetBalanceToken1 returns token1 balance.
	GetBalanceToken1(poolPath string) string

	// GetFeeGrowthGlobalX128 returns global fee growth values.
	GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint)

	// GetPositionFeeGrowthInsideLastX128 returns position fee growth.
	GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint)

	// GetObservation returns oracle observation data.
	GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64)

	// ExistsPoolPath checks if pool exists.
	ExistsPoolPath(poolPath string) bool

	// ApiGetPool returns pool data as JSON.
	ApiGetPool(poolPath string) string

	// ApiGetTWAP returns time-weighted average price.
	ApiGetTWAP(poolPath string, secondsAgo uint32) string
}

// UpdateRequest contains parameters for updating the pool implementation.
type UpdateRequest struct {
	Pool        Pool     // New pool implementation
	AllowedImpls []string // Realms allowed to update implementation
}
