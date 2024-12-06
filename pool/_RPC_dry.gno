package pool

import (
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/consts"

	plp "gno.land/p/gnoswap/pool" // pool package

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// DrySwap simulates a swap and returns the amount0, amount1 that would be received and a boolean indicating if the swap is possible
func DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	_amountSpecified string,
	_sqrtPriceLimitX96 string,
) (string, string, bool) {

	if _amountSpecified == "0" {
		return "0", "0", false
	}

	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	sqrtPriceLimitX96 := u256.MustFromDecimal(_sqrtPriceLimitX96)

	pool := GetPool(token0Path, token1Path, fee)
	slot0Start := pool.slot0

	if err := validatePriceLimits(pool, zeroForOne, sqrtPriceLimitX96); err != nil {
		return "0", "0", false
	}

	feeProtocol := getFeeProtocol(slot0Start, zeroForOne)
	feeGrowthGlobalX128 := getFeeGrowthGlobal(pool, zeroForOne)
	cache := newSwapCache(feeProtocol, pool.liquidity)

	slot0 := pool.slot0
	slot0.unlocked = false

	comp := SwapComputation{
		AmountSpecified:   amountSpecified.Clone(),
		SqrtPriceLimitX96: sqrtPriceLimitX96,
		ZeroForOne:        zeroForOne,
		ExactInput:        amountSpecified.Gt(i256.Zero()),
		InitialState:      newSwapState(amountSpecified.Clone(), feeGrowthGlobalX128.Clone(), cache.liquidityStart.Clone(), pool.slot0),
		Cache:             cache,
	}

	result, err := computeSwap(pool, comp, false)
	if err != nil {
		return "0", "0", false
	}

	// Validate balance availability
	if zeroForOne {
		if pool.balances.token1.Lt(result.Amount1.Abs()) {
			return "0", "0", false
		}
	} else {
		if pool.balances.token0.Lt(result.Amount0.Abs()) {
			return "0", "0", false
		}
	}

	// Validate non-zero amounts
	if result.Amount0.IsZero() || result.Amount1.IsZero() {
		return "0", "0", false
	}

	return amount0.ToString(), amount1.ToString(), true
}
