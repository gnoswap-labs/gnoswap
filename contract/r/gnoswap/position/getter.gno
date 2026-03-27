package position

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

// GetPositionCount returns the total number of positions.
func GetPositionCount() int {
	return getImplementation().GetPositionCount()
}

// GetPositionIDs returns a paginated list of position IDs.
func GetPositionIDs(offset, count int) []uint64 {
	return cloneUint64Slice(getImplementation().GetPositionIDs(offset, count))
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

// GetPositionTokenBalances returns the token0 balance of a position.
func GetPositionTokenBalances(positionId uint64) (int64, int64) {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0, 0
	}

	return position.Token0Balance(), position.Token1Balance()
}

func GetPositionToken0Balance(positionId uint64) int64 {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0
	}

	return position.Token0Balance()
}

func GetPositionToken1Balance(positionId uint64) int64 {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0
	}

	return position.Token1Balance()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
func GetPositionFeeGrowthInside0LastX128(positionId uint64) string {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
func GetPositionFeeGrowthInside1LastX128(positionId uint64) string {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId)
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
func GetPositionFeeGrowthInsideLastX128(positionId uint64) (string, string) {
	position, err := GetPosition(positionId)
	if err != nil {
		return "0", "0"
	}

	return position.FeeGrowthInside0LastX128(), position.FeeGrowthInside1LastX128()
}

// GetPositionLiquidity returns the liquidity amount of a position.
func GetPositionLiquidity(positionId uint64) string {
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

// GetPositionTicks returns the lower and upper ticks of a position.
func GetPositionTicks(positionId uint64) (int32, int32) {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0, 0
	}

	return position.TickLower(), position.TickUpper()
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
func GetPositionTokensOwed0(positionId uint64) int64 {
	return getImplementation().GetPositionTokensOwed0(positionId)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
func GetPositionTokensOwed1(positionId uint64) int64 {
	return getImplementation().GetPositionTokensOwed1(positionId)
}

// GetPositionTokensOwed returns the amount of tokens owed to a position.
func GetPositionTokensOwed(positionId uint64) (int64, int64) {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0, 0
	}

	return position.TokensOwed0(), position.TokensOwed1()
}

// GetUnclaimedFee returns the unclaimed fees for both tokens of a position.
func GetUnclaimedFee(positionId uint64) (string, string) {
	fee0, fee1 := getImplementation().GetUnclaimedFee(positionId)
	return fee0.ToString(), fee1.ToString()
}

// GetPositionOwner returns the owner address of a position NFT.
func GetPositionOwner(positionId uint64) address {
	return getImplementation().GetPositionOwner(positionId)
}
