package staker

import (
	pool "gno.land/r/pool"
	position "gno.land/r/position"
)

func NFTPositionInfoGetPositionInfo(tokenId string) (tickLower, tickUpper, liquidity bigint) {
	// liqPos := position.PositionGetPosition(tokenId)
	// return liqPos.tickLower, liqPos.tickUpper, liqPos.liquidity

	return position.PositionGetPositionTickLower(tokenId), position.PositionGetPositionTickUpper(tokenId), position.PositionGetPositionTickLiquidity(tokenId)
}

// func GetPositionInfo(
// 	factory IGnoswapFactory,
// 	nonfungiblePositionManager INonfungiblePositionManager,
// 	tokenId bigint,
// ) (
// 	pool IGnoswapPool,
// 	tickLower bigint,
// 	tickUpper bigint,
// 	liquidity bigint,
// ) {
// 	var token0, token1 std.Address
// 	var fee bigint

// 	_, _, token0, token1m, fee, tickLower, tickUpper, liquidity, _, _, _, _ := nonfungiblePositionManager.Positions(tokenId)

// 	pool = IGnoswapPool(
// 		PoolAddressComputeAddress(
// 			std.Address(factory),
// 			PoolAddress.PoolKey{token0: token0, token1: token1, fee: fee}
// 		)
// 	)
// }