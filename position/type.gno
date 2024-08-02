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

type IncreaseLiquidityParams struct {
	tokenId        uint64     // tokenId of the position to increase liquidity
	amount0Desired *u256.Uint // desired amount of token0 to be minted
	amount1Desired *u256.Uint // desired amount of token1 to be minted
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
	deadline       int64      // time by which the transaction must be included to effect the change
}

type DecreaseLiquidityParams struct {
	tokenId        uint64     // tokenId of the position to decrease liquidity
	liquidityRatio uint64     // percent of liquidity to decrease, i.e '25' ≈ remove 25% of liquidity
	amount0Min     *u256.Uint // minimum amount of token0 to be minted
	amount1Min     *u256.Uint // minimum amount of token1 to be minted
	deadline       int64      // time by which the transaction must be included to effect the change
	unwrapResult   bool       // whether to unwrap the token if it's wrapped native token
}
