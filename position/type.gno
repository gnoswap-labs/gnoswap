package position

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

type Position struct {
	nonce *u256.Uint // nonce for permits

	operator std.Address // address that is approved for spending this token

	poolKey string // poolPath of the pool which this has lp token

	// the tick range of the position, bounds are included
	tickLower int32
	tickUpper int32

	liquidity *u256.Uint // liquidity of the position

	// fee growth of the aggregate position as of the last action on the individual position
	feeGrowthInside0LastX128 *u256.Uint
	feeGrowthInside1LastX128 *u256.Uint

	// how many uncollected tokens are owed to the position, as of the last computation
	tokensOwed0 *u256.Uint
	tokensOwed1 *u256.Uint

	burned bool // whether the position has been burned(≈ actuall we don't burn lp token even its empty, just update flag)
}

func newPosition(nonce *u256.Uint, operator std.Address, poolKey string, tickLower, tickUpper int32, liquidity, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1 *u256.Uint, burned bool) Position {
	return Position{
		nonce:                    nonce,
		operator:                 operator,
		poolKey:                  poolKey,
		tickLower:                tickLower,
		tickUpper:                tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              tokensOwed0,
		tokensOwed1:              tokensOwed1,
		burned:                   burned,
	}
}

// isClear reports whether the position is empty
func (p Position) isClear() bool {
	return p.liquidity.IsZero() && p.tokensOwed0.IsZero() && p.tokensOwed1.IsZero()
}

type MintParams struct {
	token0         string      // token0 path for a specific pool
	token1         string      // token1 path for a specific pool
	fee            uint32      // fee for a specific pool
	tickLower      int32       // lower end of the tick range for the position
	tickUpper      int32       // upper end of the tick range for the position
	amount0Desired *u256.Uint  // desired amount of token0 to be minted
	amount1Desired *u256.Uint  // desired amount of token1 to be minted
	amount0Min     *u256.Uint  // minimum amount of token0 to be minted
	amount1Min     *u256.Uint  // minimum amount of token1 to be minted
	deadline       int64       // time by which the transaction must be included to effect the change
	mintTo         std.Address // address to mint lpToken
}

type AddLiquidityParams struct {
	poolKey        string     // poolPath of the pool which has the position
	tickLower      int32      // lower end of the tick range for the position
	tickUpper      int32      // upper end of the tick range for the position
	amount0Desired *u256.Uint // desired amount of token0 to be minted
	amount1Desired *u256.Uint // desired amount of token1 to be minted
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
}

func newAddLiquidtyParams(poolKey string, tickLower, tickUpper int32, amount0Desired, amount1Desired, amount0Min, amount1Min *u256.Uint) AddLiquidityParams {
	return AddLiquidityParams{
		poolKey:        poolKey,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
	}
}

type IncreaseLiquidityParams struct {
	tokenId        uint64     // tokenId of the position to increase liquidity
	amount0Desired *u256.Uint // desired amount of token0 to be minted
	amount1Desired *u256.Uint // desired amount of token1 to be minted
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
	deadline       int64      // time by which the transaction must be included to effect the change
}

func newIncreaseLiquidityParams(tokenId uint64, amount0Desired, amount1Desired, amount0Min, amount1Min *u256.Uint, deadline int64) IncreaseLiquidityParams {
	return IncreaseLiquidityParams{
		tokenId:        tokenId,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
	}
}

type DecreaseLiquidityParams struct {
	tokenId        uint64     // tokenId of the position to decrease liquidity
	liquidityRatio uint64     // percent of liquidity to decrease, i.e '25' ≈ remove 25% of liquidity
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
	deadline       int64      // time by which the transaction must be included to effect the change
	unwrapResult   bool       // whether to unwrap the token if it's wrapped native token
}

func newDecreaseLiquidityParams(tokenId, liquidityRatio uint64, amount0Min, amount1Min *u256.Uint, deadline int64, unwrapResult bool) DecreaseLiquidityParams {
	return DecreaseLiquidityParams{
		tokenId:        tokenId,
		liquidityRatio: liquidityRatio,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		deadline:       deadline,
		unwrapResult:   unwrapResult,
	}
}