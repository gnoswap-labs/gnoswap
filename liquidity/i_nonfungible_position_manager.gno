package liquidity

import (
	"std"
)

type INonfungiblePositionManager interface {
	Positions(bigint) (bigint, std.Address, std.Address, std.Address, bigint, bigint, bigint, bigint, bigint, bigint, bigint, bigint)
	
	Mint(MintParams) (bigint, bigint, bigint, bigint)

	IncreaseLiquidity(IncreaseLiquidityParams) (bigint, bigint, bigint)

	DecreaseLiquidity(DecreaseLiquidityParams) (bigint, bigint)

	Collect(CollectParams) (bigint, bigint)

	Burn(tokenId bigint)
}


type MintParams struct {
	token0 std.Address
	token1 std.Address
	fee bigint
	tickLower bigint
	tickUpper bigint
	amount0Desired bigint
	amount1Desired bigint
	amount0Min bigint
	amount1Min bigint
	recipient std.Address // XXX de facto: hardcoded to nft manager contract address
	deadline bigint
}

type IncreaseLiquidityParams struct {
	tokenId bigint
	amount0Desired bigint
	amount1Desired bigint
	amount0Min bigint
	amount1Min bigint
	deadline bigint
}

type DecreaseLiquidityParams struct {
	tokenId bigint
	liquidity bigint
	amount0Min bigint
	amount1Min bigint
	deadline bigint
}

type CollectParams struct {
	tokenId bigint
	recipient std.Address
	amount0Max bigint
	amount1Max bigint
}