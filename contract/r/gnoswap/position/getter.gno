package position

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

// GetPositionCount returns the total number of positions.
//
// Returns:
//   - count: total number of positions
func GetPositionCount() int {
	return getImplementation().GetPositionCount()
}

// GetPositionIDs returns a paginated list of position IDs.
//
// Parameters:
//   - offset: starting offset
//   - count: maximum number of IDs to return
//
// Returns:
//   - positionIds: paginated position IDs
func GetPositionIDs(offset, count int) []uint64 {
	return cloneUint64Slice(getImplementation().GetPositionIDs(offset, count))
}

// GetPosition returns the position data for a given position ID.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - position: copied position data
//   - err: nil on success, or an error if the position does not exist
func GetPosition(positionId uint64) (Position, error) {
	position, ok := getImplementation().GetPosition(positionId)
	if !ok {
		return Position{}, ufmt.Errorf("position %d not found", positionId)
	}

	return clonePosition(position), nil
}

// IsBurned returns whether a position has been burned.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - burned: true if the position has been burned
func IsBurned(positionId uint64) bool {
	return getImplementation().IsBurned(positionId)
}

// IsInRange returns whether a position's ticks are within the current price range.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - inRange: true if the position is currently in range
func IsInRange(positionId uint64) bool {
	return getImplementation().IsInRange(positionId)
}

// GetPositionTokenBalances returns the token balances of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - balance0: token0 balance held by the position
//   - balance1: token1 balance held by the position
func GetPositionTokenBalances(positionId uint64) (int64, int64) {
	balance0, balance1 := getImplementation().GetPositionTokenBalances(positionId)
	return balance0, balance1
}

// GetPositionToken0Balance returns the token0 balance of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - balance0: token0 balance held by the position
func GetPositionToken0Balance(positionId uint64) int64 {
	balance0, _ := GetPositionTokenBalances(positionId)
	return balance0
}

// GetPositionToken1Balance returns the token1 balance of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - balance1: token1 balance held by the position
func GetPositionToken1Balance(positionId uint64) int64 {
	_, balance1 := GetPositionTokenBalances(positionId)
	return balance1
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - feeGrowthInside0LastX128: last recorded token0 fee growth inside in Q128.128 format
func GetPositionFeeGrowthInside0LastX128(positionId uint64) string {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - feeGrowthInside1LastX128: last recorded token1 fee growth inside in Q128.128 format
func GetPositionFeeGrowthInside1LastX128(positionId uint64) string {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId)
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - feeGrowthInside0LastX128: last recorded token0 fee growth inside in Q128.128 format
//   - feeGrowthInside1LastX128: last recorded token1 fee growth inside in Q128.128 format
func GetPositionFeeGrowthInsideLastX128(positionId uint64) (string, string) {
	position, err := GetPosition(positionId)
	if err != nil {
		return "0", "0"
	}

	return position.FeeGrowthInside0LastX128(), position.FeeGrowthInside1LastX128()
}

// GetPositionLiquidity returns the liquidity amount of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - liquidity: liquidity amount of the position
func GetPositionLiquidity(positionId uint64) string {
	return getImplementation().GetPositionLiquidity(positionId)
}

// GetPositionOperator returns the operator address of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - operator: approved operator address for the position
func GetPositionOperator(positionId uint64) address {
	return getImplementation().GetPositionOperator(positionId)
}

// GetPositionPoolKey returns the pool key of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - poolKey: pool key associated with the position
func GetPositionPoolKey(positionId uint64) string {
	return getImplementation().GetPositionPoolKey(positionId)
}

// GetPositionTickLower returns the lower tick of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tickLower: lower tick boundary of the position
func GetPositionTickLower(positionId uint64) int32 {
	return getImplementation().GetPositionTickLower(positionId)
}

// GetPositionTickUpper returns the upper tick of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tickUpper: upper tick boundary of the position
func GetPositionTickUpper(positionId uint64) int32 {
	return getImplementation().GetPositionTickUpper(positionId)
}

// GetPositionTicks returns the lower and upper ticks of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tickLower: lower tick boundary of the position
//   - tickUpper: upper tick boundary of the position
func GetPositionTicks(positionId uint64) (int32, int32) {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0, 0
	}

	return position.TickLower(), position.TickUpper()
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tokensOwed0: token0 amount owed to the position
func GetPositionTokensOwed0(positionId uint64) int64 {
	return getImplementation().GetPositionTokensOwed0(positionId)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tokensOwed1: token1 amount owed to the position
func GetPositionTokensOwed1(positionId uint64) int64 {
	return getImplementation().GetPositionTokensOwed1(positionId)
}

// GetPositionTokensOwed returns the amount of tokens owed to a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tokensOwed0: token0 amount owed to the position
//   - tokensOwed1: token1 amount owed to the position
func GetPositionTokensOwed(positionId uint64) (int64, int64) {
	position, err := GetPosition(positionId)
	if err != nil {
		return 0, 0
	}

	return position.TokensOwed0(), position.TokensOwed1()
}

// GetUnclaimedFee returns the unclaimed fees for both tokens of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - fee0: unclaimed token0 fee amount
//   - fee1: unclaimed token1 fee amount
func GetUnclaimedFee(positionId uint64) (string, string) {
	fee0, fee1 := getImplementation().GetUnclaimedFee(positionId)
	return fee0.ToString(), fee1.ToString()
}

// GetPositionOwner returns the owner address of a position NFT.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - owner: owner address of the position NFT
func GetPositionOwner(positionId uint64) address {
	return getImplementation().GetPositionOwner(positionId)
}
