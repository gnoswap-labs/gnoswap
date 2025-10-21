package position

import u256 "gno.land/p/gnoswap/uint256"

func GetPosition(positionId uint64) (Position, bool) {
	return getImplementation().GetPosition(positionId)
}

func MustGetPosition(positionId uint64) Position {
	return getImplementation().MustGetPosition(positionId)
}

func IsBurned(positionId uint64) bool {
	return getImplementation().IsBurned(positionId)
}

func IsInRange(positionId uint64) bool {
	return getImplementation().IsInRange(positionId)
}

func GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId)
}

func GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId)
}

func GetPositionLiquidity(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionLiquidity(positionId)
}

func GetPositionOperator(positionId uint64) string {
	return getImplementation().GetPositionOperator(positionId)
}

func GetPositionPoolKey(positionId uint64) string {
	return getImplementation().GetPositionPoolKey(positionId)
}

func GetPositionTickLower(positionId uint64) int32 {
	return getImplementation().GetPositionTickLower(positionId)
}

func GetPositionTickUpper(positionId uint64) int32 {
	return getImplementation().GetPositionTickUpper(positionId)
}

func GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed0(positionId)
}

func GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed1(positionId)
}

func GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetUnclaimedFee(positionId)
}

func ApiGetPosition(positionId uint64) string {
	return getImplementation().ApiGetPosition(positionId)
}

func ApiGetPositionUnclaimedFeeByPositionID(positionId uint64) string {
	return getImplementation().ApiGetPositionUnclaimedFeeByPositionID(positionId)
}
