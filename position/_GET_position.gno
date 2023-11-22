package position

func PositionGetPosition(tokenId uint64) Position {
	return positions[tokenId]
}

func PositionGetPositionLiquidity(tokenId uint64) bigint {
	return positions[tokenId].liquidity
}

func PositionGetPositionPoolKey(tokenId uint64) string {
	return positions[tokenId].poolKey
}

func PositionGetPositionTickLower(tokenId uint64) int32 {
	return positions[tokenId].tickLower
}

func PositionGetPositionTickUpper(tokenId uint64) int32 {
	return positions[tokenId].tickUpper
}

func PositionGetPositionFeeGrowthInside0LastX128(tokenId uint64) bigint {
	return positions[tokenId].feeGrowthInside0LastX128
}

func PositionGetPositionFeeGrowthInside1LastX128(tokenId uint64) bigint {
	return positions[tokenId].feeGrowthInside1LastX128
}

func PositionGetPositionTokensOwed0(tokenId uint64) bigint {
	return positions[tokenId].tokensOwed0
}

func PositionGetPositionTokensOwed1(tokenId uint64) bigint {
	return positions[tokenId].tokensOwed1
}

func PositionGetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity bigint) (bigint, bigint) {
	return liquidityAmountsGetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity)
}
