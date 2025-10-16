package position

import (
	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gnft"
	pl "gno.land/r/gnoswap/v1/pool"
)

func PositionGetPosition(positionId uint64) Position {
	position, ok := GetPosition(positionId)
	if !ok {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("positionId(%d) does not exist", positionId),
		))
	}
	return position
}

func PositionGetPositionOperator(positionId uint64) address {
	return MustGetPosition(positionId).operator
}

func PositionGetPositionPoolKey(positionId uint64) string {
	return MustGetPosition(positionId).poolKey
}

func PositionGetPositionTickLower(positionId uint64) int32 {
	return MustGetPosition(positionId).tickLower
}

func PositionGetPositionTickUpper(positionId uint64) int32 {
	return MustGetPosition(positionId).tickUpper
}

func PositionGetPositionLiquidity(positionId uint64) *u256.Uint {
	return MustGetPosition(positionId).liquidity
}

func PositionGetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return MustGetPosition(positionId).feeGrowthInside0LastX128
}

func PositionGetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return MustGetPosition(positionId).feeGrowthInside1LastX128
}

func PositionGetPositionTokensOwed0(positionId uint64) *u256.Uint {
	return MustGetPosition(positionId).tokensOwed0
}

func PositionGetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return MustGetPosition(positionId).tokensOwed1
}

func PositionGetPositionIsBurned(positionId uint64) bool {
	return MustGetPosition(positionId).burned
}

func PositionIsInRange(positionId uint64) bool {
	position := MustGetPosition(positionId)
	poolPath := position.poolKey
	poolCurrentTick := pl.GetSlot0Tick(poolPath)

	return position.tickLower <= poolCurrentTick && poolCurrentTick < position.tickUpper
}

func PositionGetPositionOwner(positionId uint64) address {
	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		panic(newErrorWithDetail(
			errDataNotFound, err.Error()))
	}
	return owner
}

func PositionGetPositionOperatorStr(positionId uint64) string {
	return PositionGetPositionOperator(positionId).String()
}

func PositionGetPositionLiquidityStr(positionId uint64) string {
	return PositionGetPositionLiquidity(positionId).ToString()
}

func PositionGetPositionFeeGrowthInside0LastX128Str(positionId uint64) string {
	return PositionGetPositionFeeGrowthInside0LastX128(positionId).ToString()
}

func PositionGetPositionFeeGrowthInside1LastX128Str(positionId uint64) string {
	return PositionGetPositionFeeGrowthInside1LastX128(positionId).ToString()
}

func PositionGetPositionTokensOwed0Str(positionId uint64) string {
	return PositionGetPositionTokensOwed0(positionId).ToString()
}

func PositionGetPositionTokensOwed1Str(positionId uint64) string {
	return PositionGetPositionTokensOwed1(positionId).ToString()
}
