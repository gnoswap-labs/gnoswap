package position


func PositionGetPosition(tokenId string) Position {
	return positions[tokenId].(Position)
}

func PositionGetPositionTickLower(tokenId string) bigint {
	return positions[tokenId].tickLower
}

func PositionGetPositionTickUpper(tokenId string) bigint {
	return positions[tokenId].tickUpper
}

func PositionGetPositionTickLiquidity(tokenId string) bigint {
	return positions[tokenId].liquidity
}