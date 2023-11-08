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
