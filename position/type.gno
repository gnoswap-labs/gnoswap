package position

import (
	"std"
)

type Position struct {
	nonce bigint

	operator std.Address

	poolKey string

	tickLower int32
	tickUpper int32

	liquidity bigint

	feeGrowthInside0LastX128 bigint
	feeGrowthInside1LastX128 bigint

	tokensOwed0 bigint
	tokensOwed1 bigint

	burned bool
}

type MintParams struct { // r3v4_xxx: private?
	token0         string
	token1         string
	fee            uint16
	tickLower      int32
	tickUpper      int32
	amount0Desired bigint
	amount1Desired bigint
	amount0Min     bigint
	amount1Min     bigint
	// recipient std.Address // XXX de facto: hardcoded to nft manager contract address
	deadline bigint
}

type AddLiquidityParams struct { // r3v4_xxx: private?
	poolKey        string
	recipient      std.Address // XXX de facto: hardcoded to nft manager contract address
	tickLower      int32
	tickUpper      int32
	amount0Desired bigint
	amount1Desired bigint
	amount0Min     bigint
	amount1Min     bigint
}

type IncreaseLiquidityParams struct { // r3v4_xxx: private?
	tokenId        uint64
	amount0Desired bigint
	amount1Desired bigint
	amount0Min     bigint
	amount1Min     bigint
	deadline       bigint
}

type DecreaseLiquidityParams struct { // r3v4_xxx: private?
	tokenId   uint64
	liquidity bigint
	deadline  bigint
}
