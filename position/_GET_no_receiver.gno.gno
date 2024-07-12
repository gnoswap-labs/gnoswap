package position

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/pool"
)

// type Position
func PositionGetPosition(tokenId uint64) Position {
	return positions[tokenId]
}

func PositionGetPositionNonce(tokenId uint64) *u256.Uint {
	return positions[tokenId].nonce
}

func PositionGetPositionOperator(tokenId uint64) std.Address {
	return positions[tokenId].operator
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

func PositionGetPositionLiquidity(tokenId uint64) *u256.Uint {
	return positions[tokenId].liquidity
}

func PositionGetPositionFeeGrowthInside0LastX128(tokenId uint64) *u256.Uint {
	return positions[tokenId].feeGrowthInside0LastX128
}

func PositionGetPositionFeeGrowthInside1LastX128(tokenId uint64) *u256.Uint {
	return positions[tokenId].feeGrowthInside1LastX128
}

func PositionGetPositionTokensOwed0(tokenId uint64) *u256.Uint {
	return positions[tokenId].tokensOwed0
}

func PositionGetPositionTokensOwed1(tokenId uint64) *u256.Uint {
	return positions[tokenId].tokensOwed1
}

func PositionIsInRange(tokenId uint64) bool {
	position := positions[tokenId]
	poolPath := position.poolKey
	poolCurrentTick := pl.PoolGetSlot0Tick(poolPath)

	if position.tickLower <= poolCurrentTick && poolCurrentTick <= position.tickUpper {
		return true
	}

	return false
}
