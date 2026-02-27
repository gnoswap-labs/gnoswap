package position

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
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
//   - offset: starting index for pagination
//   - count: number of position IDs to return
//
// Returns:
//   - positionIDs: slice of position IDs
func GetPositionIDs(offset, count int) []uint64 {
	return getImplementation().GetPositionIDs(offset, count)
}

// GetPosition returns the position data for a given position ID.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - position: position data
//   - err: error if position not found
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
//   - burned: true if position has been burned
func IsBurned(positionId uint64) bool {
	return getImplementation().IsBurned(positionId)
}

// IsInRange returns whether a position's ticks are within the current price range.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - inRange: true if position is within current price range
func IsInRange(positionId uint64) bool {
	return getImplementation().IsInRange(positionId)
}

// GetPositionTokenBalances returns the token balances of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - token0Balance: balance of token0
//   - token1Balance: balance of token1
func GetPositionTokenBalances(positionId uint64) (string, string) {
	position, err := GetPosition(positionId)
	if err != nil {
		return "", ""
	}

	return position.Token0Balance().ToString(), position.Token1Balance().ToString()
}

// GetPositionToken0Balance returns the token0 balance of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - balance: token0 balance
func GetPositionToken0Balance(positionId uint64) *u256.Uint {
	position, err := GetPosition(positionId)
	if err != nil {
		return u256.Zero()
	}

	return position.Token0Balance().Clone()
}

// GetPositionToken1Balance returns the token1 balance of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - balance: token1 balance
func GetPositionToken1Balance(positionId uint64) *u256.Uint {
	position, err := GetPosition(positionId)
	if err != nil {
		return u256.Zero()
	}

	return position.Token1Balance().Clone()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - feeGrowth: fee growth inside for token0 in X128 format
func GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId).Clone()
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - feeGrowth: fee growth inside for token1 in X128 format
func GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId).Clone()
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - feeGrowth0: fee growth inside for token0 in X128 format
//   - feeGrowth1: fee growth inside for token1 in X128 format
func GetPositionFeeGrowthInsideLastX128(positionId uint64) (*u256.Uint, *u256.Uint) {
	position, err := GetPosition(positionId)
	if err != nil {
		return u256.Zero(), u256.Zero()
	}

	return position.FeeGrowthInside0LastX128().Clone(), position.FeeGrowthInside1LastX128().Clone()
}

// GetPositionLiquidity returns the liquidity amount of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - liquidity: liquidity amount of the position
func GetPositionLiquidity(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionLiquidity(positionId).Clone()
}

// GetPositionOperator returns the operator address of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - operator: address approved for spending this position
func GetPositionOperator(positionId uint64) address {
	return getImplementation().GetPositionOperator(positionId)
}

// GetPositionPoolKey returns the pool key of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - poolKey: pool path identifier
func GetPositionPoolKey(positionId uint64) string {
	return getImplementation().GetPositionPoolKey(positionId)
}

// GetPositionTickLower returns the lower tick of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tickLower: lower tick boundary
func GetPositionTickLower(positionId uint64) int32 {
	return getImplementation().GetPositionTickLower(positionId)
}

// GetPositionTickUpper returns the upper tick of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tickUpper: upper tick boundary
func GetPositionTickUpper(positionId uint64) int32 {
	return getImplementation().GetPositionTickUpper(positionId)
}

// GetPositionTicks returns the lower and upper ticks of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tickLower: lower tick boundary
//   - tickUpper: upper tick boundary
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
//   - tokensOwed: amount of token0 owed
func GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed0(positionId).Clone()
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tokensOwed: amount of token1 owed
func GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return getImplementation().GetPositionTokensOwed1(positionId).Clone()
}

// GetPositionTokensOwed returns the amount of tokens owed to a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - tokensOwed0: amount of token0 owed
//   - tokensOwed1: amount of token1 owed
func GetPositionTokensOwed(positionId uint64) (*u256.Uint, *u256.Uint) {
	position, err := GetPosition(positionId)
	if err != nil {
		return u256.Zero(), u256.Zero()
	}

	return position.TokensOwed0().Clone(), position.TokensOwed1().Clone()
}

// GetUnclaimedFee returns the unclaimed fees for both tokens of a position.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - unclaimedFee0: unclaimed fee amount for token0
//   - unclaimedFee1: unclaimed fee amount for token1
func GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	unclaimedFee0, unclaimedFee1 := getImplementation().GetUnclaimedFee(positionId)
	return unclaimedFee0.Clone(), unclaimedFee1.Clone()
}

// GetPositionOwner returns the owner address of a position NFT.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - owner: address that owns the position NFT
func GetPositionOwner(positionId uint64) address {
	return getImplementation().GetPositionOwner(positionId)
}
