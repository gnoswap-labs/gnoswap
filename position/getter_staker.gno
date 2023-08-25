// STAKER CONTRACT USES BELOW FUNCTIONS IN ITS LOGIC
package position

func PositionGetPosition(tokenId bigint) Position {
	return positions[tokenId]
}

func PositionGetPositionTickLower(tokenId bigint) bigint {
	return positions[tokenId].tickLower
}

func PositionGetPositionTickUpper(tokenId bigint) bigint {
	return positions[tokenId].tickUpper
}

func PositionGetPositionTickLiquidity(tokenId bigint) bigint {
	return positions[tokenId].liquidity
}
