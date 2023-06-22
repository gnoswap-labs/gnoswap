package position

import (
	"std"
)

type Position struct {
	nonce bigint

	operator std.Address

	poolKey string

	tickLower bigint
	tickUpper bigint

	liquidity bigint

	feeGrowthInside0LastX128 bigint
	feeGrowthInside1LastX128 bigint

	tokensOwed0 bigint
	tokensOwed1 bigint
}

type MintParams struct {
	token0         string
	token1         string
	fee            bigint
	tickLower      bigint
	tickUpper      bigint
	amount0Desired bigint
	amount1Desired bigint
	amount0Min     bigint
	amount1Min     bigint
	// recipient std.Address // XXX de facto: hardcoded to nft manager contract address
	deadline bigint
}

type AddLiquidityParams struct {
	poolKey        string
	recipient      std.Address // XXX de facto: hardcoded to nft manager contract address
	tickLower      bigint
	tickUpper      bigint
	amount0Desired bigint
	amount1Desired bigint
	amount0Min     bigint
	amount1Min     bigint
}

type IncreaseLiquidityParams struct {
	tokenId        bigint
	amount0Desired bigint
	amount1Desired bigint
	amount0Min     bigint
	amount1Min     bigint
	deadline       bigint
}

type DecreaseLiquidityParams struct {
	tokenId    bigint
	liquidity  bigint
	amount0Min bigint
	amount1Min bigint
	deadline   bigint
}

type CollectParams struct {
	tokenId    bigint
	recipient  std.Address
	amount0Max bigint
	amount1Max bigint
}
