package position

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/gnft"
	pl "gno.land/r/gnoswap/v1/pool"
)

func PositionGetPosition(positionId int64) Position {
	position, _ := GetPosition(positionId)
	return position
}

func PositionGetPositionNonce(positionId int64) *u256.Uint {
	return MustGetPosition(positionId).nonce
}

func PositionGetPositionOperator(positionId int64) std.Address {
	return MustGetPosition(positionId).operator
}

func PositionGetPositionPoolKey(positionId int64) string {
	return MustGetPosition(positionId).poolKey
}

func PositionGetPositionTickLower(positionId int64) int32 {
	return MustGetPosition(positionId).tickLower
}

func PositionGetPositionTickUpper(positionId int64) int32 {
	return MustGetPosition(positionId).tickUpper
}

func PositionGetPositionLiquidity(positionId int64) *u256.Uint {
	return MustGetPosition(positionId).liquidity
}

func PositionGetPositionFeeGrowthInside0LastX128(positionId int64) *u256.Uint {
	return MustGetPosition(positionId).feeGrowthInside0LastX128
}

func PositionGetPositionFeeGrowthInside1LastX128(positionId int64) *u256.Uint {
	return MustGetPosition(positionId).feeGrowthInside1LastX128
}

func PositionGetPositionTokensOwed0(positionId int64) *u256.Uint {
	return MustGetPosition(positionId).tokensOwed0
}

func PositionGetPositionTokensOwed1(positionId int64) *u256.Uint {
	return MustGetPosition(positionId).tokensOwed1
}

func PositionGetPositionIsBurned(positionId int64) bool {
	return MustGetPosition(positionId).burned
}

func PositionIsInRange(positionId int64) bool {
	position := MustGetPosition(positionId)
	poolPath := position.poolKey
	poolCurrentTick := pl.PoolGetSlot0Tick(poolPath)

	return position.tickLower <= poolCurrentTick && poolCurrentTick < position.tickUpper
}

func PositionGetPositionOwner(positionId int64) std.Address {
	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		panic(newErrorWithDetail(
			errDataNotFound, err.Error()))
	}
	return owner
}

func PositionGetPositionNonceStr(positionId int64) string {
	return PositionGetPositionNonce(positionId).ToString()
}

func PositionGetPositionOperatorStr(positionId int64) string {
	return PositionGetPositionOperator(positionId).String()
}

func PositionGetPositionLiquidityStr(positionId int64) string {
	return PositionGetPositionLiquidity(positionId).ToString()
}

func PositionGetPositionFeeGrowthInside0LastX128Str(positionId int64) string {
	return PositionGetPositionFeeGrowthInside0LastX128(positionId).ToString()
}

func PositionGetPositionFeeGrowthInside1LastX128Str(positionId int64) string {
	return PositionGetPositionFeeGrowthInside1LastX128(positionId).ToString()
}

func PositionGetPositionTokensOwed0Str(positionId int64) string {
	return PositionGetPositionTokensOwed0(positionId).ToString()
}

func PositionGetPositionTokensOwed1Str(positionId int64) string {
	return PositionGetPositionTokensOwed1(positionId).ToString()
}
