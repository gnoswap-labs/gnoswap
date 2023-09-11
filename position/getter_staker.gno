// STAKER CONTRACT USES BELOW FUNCTIONS IN ITS LOGIC
package position

func PositionGetPosition(tokenId uint64) Position {
	return positions[tokenId]
}

func PositionGetPositionTickLower(tokenId uint64) int32 {
	return positions[tokenId].tickLower
}

func PositionGetPositionTickUpper(tokenId uint64) int32 {
	return positions[tokenId].tickUpper
}

func PositionGetPositionLiquidity(tokenId uint64) bigint {
	return positions[tokenId].liquidity
}

func PositionGetPositionPoolKey(tokenId uint64) string {
	return positions[tokenId].poolKey
}
