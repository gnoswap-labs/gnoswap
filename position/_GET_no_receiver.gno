package position

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gnft"
)

// type Position
func PositionGetPosition(tokenId uint64) Position {
	position, _ := GetPosition(tokenId)
	return position
}

func PositionGetPositionNonce(tokenId uint64) *u256.Uint {
	position := MustGetPosition(tokenId)
	return position.nonce
}

func PositionGetPositionOperator(tokenId uint64) std.Address {
	position := MustGetPosition(tokenId)
	return position.operator
}

func PositionGetPositionPoolKey(tokenId uint64) string {
	position := MustGetPosition(tokenId)
	return position.poolKey
}

func PositionGetPositionTickLower(tokenId uint64) int32 {
	position := MustGetPosition(tokenId)
	return position.tickLower
}

func PositionGetPositionTickUpper(tokenId uint64) int32 {
	position := MustGetPosition(tokenId)
	return position.tickUpper
}

func PositionGetPositionLiquidity(tokenId uint64) *u256.Uint {
	position := MustGetPosition(tokenId)
	return position.liquidity
}

func PositionGetPositionFeeGrowthInside0LastX128(tokenId uint64) *u256.Uint {
	position := MustGetPosition(tokenId)
	return position.feeGrowthInside0LastX128
}

func PositionGetPositionFeeGrowthInside1LastX128(tokenId uint64) *u256.Uint {
	position := MustGetPosition(tokenId)
	return position.feeGrowthInside1LastX128
}

func PositionGetPositionTokensOwed0(tokenId uint64) *u256.Uint {
	position := MustGetPosition(tokenId)
	return position.tokensOwed0
}

func PositionGetPositionTokensOwed1(tokenId uint64) *u256.Uint {
	position := MustGetPosition(tokenId)
	return position.tokensOwed1
}

func PositionIsInRange(tokenId uint64) bool {
	position := MustGetPosition(tokenId)
	poolPath := position.poolKey
	poolCurrentTick := pl.PoolGetSlot0Tick(poolPath)

	if position.tickLower <= poolCurrentTick && poolCurrentTick <= position.tickUpper {
		return true
	}

	return false
}

func PositionGetPositionOwner(tokenId uint64) std.Address {
	return gnft.OwnerOf(tokenIdFrom(tokenId))
}
