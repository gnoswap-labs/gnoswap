package position

import u256 "gno.land/p/gnoswap/uint256"

// GetPosition returns the position data for a given position ID.
func GetPosition(positionId uint64) (Position, bool) {
	return getImplementation().GetPosition(positionId)
}

// IsBurned returns whether a position has been burned.
func IsBurned(positionId uint64) bool {
	return getImplementation().IsBurned(positionId)
}

// IsInRange returns whether a position's ticks are within the current price range.
func IsInRange(positionId uint64) bool {
	return getImplementation().IsInRange(positionId)
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
func GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
func GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId)
}

// GetPositionLiquidity returns the liquidity amount of a position.
func GetPositionLiquidity(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionLiquidity(positionId)
}

// GetPositionOperator returns the operator address of a position.
func GetPositionOperator(positionId uint64) address {
	return getImplementation().GetPositionOperator(positionId)
}

// GetPositionPoolKey returns the pool key of a position.
func GetPositionPoolKey(positionId uint64) string {
	return getImplementation().GetPositionPoolKey(positionId)
}

// GetPositionTickLower returns the lower tick of a position.
func GetPositionTickLower(positionId uint64) int32 {
	return getImplementation().GetPositionTickLower(positionId)
}

// GetPositionTickUpper returns the upper tick of a position.
func GetPositionTickUpper(positionId uint64) int32 {
	return getImplementation().GetPositionTickUpper(positionId)
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
func GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed0(positionId)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
func GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed1(positionId)
}

// GetUnclaimedFee returns the unclaimed fees for both tokens of a position.
func GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetUnclaimedFee(positionId)
}

// GetPositionOwner returns the owner address of a position NFT.
func GetPositionOwner(positionId uint64) address {
	return getImplementation().GetPositionOwner(positionId)
}

// ApiGetPosition returns position data as JSON.
func ApiGetPosition(positionId uint64) string {
	return getImplementation().ApiGetPosition(positionId)
}

// ApiGetPositionUnclaimedFeeByPositionID returns unclaimed fees for a position as JSON.
func ApiGetPositionUnclaimedFeeByPositionID(positionId uint64) string {
	return getImplementation().ApiGetPositionUnclaimedFeeByPositionID(positionId)
}
