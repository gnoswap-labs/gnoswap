package position

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

// GetPositionCount returns the total number of positions.
func GetPositionCount() int {
	return getImplementation().GetPositionCount()
}

// GetPositionIDs returns a paginated list of position IDs.
func GetPositionIDs(offset, count int) []uint64 {
	return getImplementation().GetPositionIDs(offset, count)
}

// GetPosition returns the position data for a given position ID.
func GetPosition(positionId uint64) (Position, error) {
	position, ok := getImplementation().GetPosition(positionId)
	if !ok {
		return Position{}, ufmt.Errorf("position %d not found", positionId)
	}

	return clonePosition(position), nil
}

// IsBurned returns whether a position has been burned.
func IsBurned(positionId uint64) bool {
	return getImplementation().IsBurned(positionId)
}

// IsInRange returns whether a position's ticks are within the current price range.
func IsInRange(positionId uint64) bool {
	return getImplementation().IsInRange(positionId)
}

func GetPositionToken0Balance(positionId uint64) *u256.Uint {
	position, err := GetPosition(positionId)
	if err != nil {
		return u256.Zero()
	}

	return position.Token0Balance().Clone()
}

func GetPositionToken1Balance(positionId uint64) *u256.Uint {
	position, err := GetPosition(positionId)
	if err != nil {
		return u256.Zero()
	}

	return position.Token1Balance().Clone()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
func GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId).Clone()
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
func GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId).Clone()
}

// GetPositionLiquidity returns the liquidity amount of a position.
func GetPositionLiquidity(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionLiquidity(positionId).Clone()
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
	return getImplementation().GetPositionTokensOwed0(positionId).Clone()
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
func GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed1(positionId).Clone()
}

// GetUnclaimedFee returns the unclaimed fees for both tokens of a position.
func GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	unclaimedFee0, unclaimedFee1 := getImplementation().GetUnclaimedFee(positionId)
	return unclaimedFee0.Clone(), unclaimedFee1.Clone()
}

// GetPositionOwner returns the owner address of a position NFT.
func GetPositionOwner(positionId uint64) address {
	return getImplementation().GetPositionOwner(positionId)
}
