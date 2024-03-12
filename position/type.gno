package position

import (
	"std"

	u256 "gno.land/p/big/uint256"
)

type Position struct {
	nonce *u256.Uint // uint96

	operator std.Address

	poolKey string

	tickLower int32
	tickUpper int32

	liquidity *u256.Uint // uint128

	feeGrowthInside0LastX128 *u256.Uint // uint256
	feeGrowthInside1LastX128 *u256.Uint // uint256

	tokensOwed0 *u256.Uint // uint128
	tokensOwed1 *u256.Uint // uint128

	burned bool
}

func (p Position) isClear() bool {
	return p.liquidity.IsZero() && p.tokensOwed0.IsZero() && p.tokensOwed1.IsZero()
}

type MintParams struct {
	token0         string
	token1         string
	fee            uint32
	tickLower      int32
	tickUpper      int32
	amount0Desired *u256.Uint // uint256
	amount1Desired *u256.Uint // uint256
	amount0Min     *u256.Uint // uint256
	amount1Min     *u256.Uint // uint256
	deadline       int64
	mintTo         std.Address
}

type AddLiquidityParams struct {
	poolKey        string
	tickLower      int32
	tickUpper      int32
	amount0Desired *u256.Uint // uint256
	amount1Desired *u256.Uint // uint256
	amount0Min     *u256.Uint // uint256
	amount1Min     *u256.Uint // uint256
}

type IncreaseLiquidityParams struct {
	tokenId        uint64
	amount0Desired *u256.Uint // uint256
	amount1Desired *u256.Uint // uint256
	amount0Min     *u256.Uint // uint256
	amount1Min     *u256.Uint // uint256
	deadline       int64
}

type DecreaseLiquidityParams struct {
	tokenId      uint64
	liquidity    *u256.Uint // uint128
	amount0Min   *u256.Uint // uint256
	amount1Min   *u256.Uint // uint256
	deadline     int64
	unwrapResult bool
}
