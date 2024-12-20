package position

// type Position
func PositionGetPositionNonceStr(tokenId uint64) string {
	return MustGetPosition(tokenId).nonce.ToString()
}

func PositionGetPositionLiquidityStr(tokenId uint64) string {
	return MustGetPosition(tokenId).liquidity.ToString()
}

func PositionGetPositionFeeGrowthInside0LastX128Str(tokenId uint64) string {
	return MustGetPosition(tokenId).feeGrowthInside0LastX128.ToString()
}

func PositionGetPositionFeeGrowthInside1LastX128Str(tokenId uint64) string {
	return MustGetPosition(tokenId).feeGrowthInside1LastX128.ToString()
}

func PositionGetPositionTokensOwed0Str(tokenId uint64) string {
	return MustGetPosition(tokenId).tokensOwed0.ToString()
}

func PositionGetPositionTokensOwed1Str(tokenId uint64) string {
	return MustGetPosition(tokenId).tokensOwed1.ToString()
}
