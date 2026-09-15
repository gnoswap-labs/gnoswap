package position

import (
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

// GetPositions returns a read-only view of all positions.
//
// Returns:
//   - positions: read-only tree keyed by decimal position ID; callers paginate with IterateByOffset
func GetPositions() *rotree.ReadOnlyTree {
	return getImplementation().GetPositions()
}

// IsBurned reports whether the position's empty-position marker is set.
//
// Parameters:
//   - positionId: position NFT token ID
//
// Returns:
//   - burned: whether the position's empty-position marker is set
//   - err: non-nil when positionId cannot be resolved
func IsBurned(positionId uint64) (bool, error) {
	return getImplementation().IsBurned(positionId)
}

// IsInRange reports whether a position's ticks contain the current pool tick.
//
// Parameters:
//   - positionId: position NFT token ID
//
// Returns:
//   - inRange: whether the position is currently in range
//   - err: non-nil when positionId cannot be resolved or the associated pool tick cannot be read
func IsInRange(positionId uint64) (bool, error) {
	return getImplementation().IsInRange(positionId)
}

// GetPositionTokenBalances calculates the current token0/token1 balances for
// a position from its liquidity, tick range, and pool price.
//
// These are derived balances, not permanently stored token amounts.
//
// Parameters:
//   - positionId: position NFT token ID
//
// Returns:
//   - balance0: current token0 balance
//   - balance1: current token1 balance
//   - err: non-nil when positionId cannot be resolved
func GetPositionTokenBalances(positionId uint64) (int64, int64, error) {
	return getImplementation().GetPositionTokenBalances(positionId)
}

// GetPositionToken0Balance returns the token0 balance associated with a position.
//
// Parameters:
//   - positionId: position NFT token ID
//
// Returns:
//   - balance: token0 balance
//   - err: non-nil when positionId cannot be resolved
func GetPositionToken0Balance(positionId uint64) (int64, error) {
	balance0, _, err := GetPositionTokenBalances(positionId)
	if err != nil {
		return 0, err
	}

	return balance0, nil
}

// GetPositionToken1Balance returns the token1 balance associated with a position.
//
// Parameters:
//   - positionId: position NFT token ID
//
// Returns:
//   - balance: token1 balance
//   - err: non-nil when positionId cannot be resolved
func GetPositionToken1Balance(positionId uint64) (int64, error) {
	_, balance1, err := GetPositionTokenBalances(positionId)
	if err != nil {
		return 0, err
	}

	return balance1, nil
}

// GetPositionFeeGrowthInside0LastX128 returns the last fee-growth checkpoint inside the position's range for token0.
//
// Parameters:
//   - positionId: position NFT token ID whose token0 fee-growth checkpoint is queried
//
// Returns:
//   - feeGrowthInside0LastX128: token0 fee-growth checkpoint, represented as a decimal string
//   - err: non-nil when positionId cannot be resolved
func GetPositionFeeGrowthInside0LastX128(positionId uint64) (string, error) {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(positionId)
}

// GetPositionFeeGrowthInside1LastX128 returns the last fee-growth checkpoint inside the position's range for token1.
//
// Parameters:
//   - positionId: position NFT token ID whose token1 fee-growth checkpoint is queried
//
// Returns:
//   - feeGrowthInside1LastX128: token1 fee-growth checkpoint, represented as a decimal string
//   - err: non-nil when positionId cannot be resolved
func GetPositionFeeGrowthInside1LastX128(positionId uint64) (string, error) {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(positionId)
}

// GetPositionFeeGrowthInsideLastX128 returns the last fee-growth checkpoints inside the position's range for both tokens.
//
// Parameters:
//   - positionId: position NFT token ID whose fee-growth checkpoints are queried
//
// Returns:
//   - feeGrowthInside0LastX128: token0 fee-growth checkpoint, represented as a decimal string
//   - feeGrowthInside1LastX128: token1 fee-growth checkpoint, represented as a decimal string
//   - err: non-nil when positionId cannot be resolved
func GetPositionFeeGrowthInsideLastX128(positionId uint64) (string, string, error) {
	return getImplementation().GetPositionFeeGrowthInsideLastX128(positionId)
}

// GetPositionLiquidity returns the stored liquidity amount of a position.
//
// Parameters:
//   - positionId: position NFT token ID whose liquidity is queried
//
// Returns:
//   - liquidity: position liquidity, represented as a decimal string
//   - err: non-nil when positionId cannot be resolved
func GetPositionLiquidity(positionId uint64) (string, error) {
	return getImplementation().GetPositionLiquidity(positionId)
}

// GetPositionOperator returns the approved operator address for a position.
//
// Parameters:
//   - positionId: position NFT token ID whose operator is queried
//
// Returns:
//   - operator: approved operator address; the zero address means no operator is set
//   - err: non-nil when positionId cannot be resolved
func GetPositionOperator(positionId uint64) (address, error) {
	return getImplementation().GetPositionOperator(positionId)
}

// GetPositionPoolKey returns the pool key associated with a position.
//
// Parameters:
//   - positionId: position NFT token ID whose pool association is queried
//
// Returns:
//   - poolKey: canonical pool key used by the position
//   - err: non-nil when positionId cannot be resolved
func GetPositionPoolKey(positionId uint64) (string, error) {
	return getImplementation().GetPositionPoolKey(positionId)
}

// GetPositionTickLower returns the lower tick boundary of a position.
//
// Parameters:
//   - positionId: position NFT token ID whose lower tick is queried
//
// Returns:
//   - tickLower: lower tick boundary of the position's price range
//   - err: non-nil when positionId cannot be resolved
func GetPositionTickLower(positionId uint64) (int32, error) {
	return getImplementation().GetPositionTickLower(positionId)
}

// GetPositionTickUpper returns the upper tick boundary of a position.
//
// Parameters:
//   - positionId: position NFT token ID whose upper tick is queried
//
// Returns:
//   - tickUpper: upper tick boundary of the position's price range
//   - err: non-nil when positionId cannot be resolved
func GetPositionTickUpper(positionId uint64) (int32, error) {
	return getImplementation().GetPositionTickUpper(positionId)
}

// GetPositionTicks returns the lower and upper tick boundaries of a position.
//
// Parameters:
//   - positionId: position NFT token ID whose tick range is queried
//
// Returns:
//   - tickLower: lower tick boundary of the position's price range
//   - tickUpper: upper tick boundary of the position's price range
//   - err: non-nil when positionId cannot be resolved
func GetPositionTicks(positionId uint64) (int32, int32, error) {
	return getImplementation().GetPositionTicks(positionId)
}

// GetPositionTokensOwed0 returns the token0 amount accrued and owed to a position.
//
// Parameters:
//   - positionId: position NFT token ID whose token0 debt is queried
//
// Returns:
//   - tokensOwed0: token0 amount currently owed to the position
//   - err: non-nil when positionId cannot be resolved
func GetPositionTokensOwed0(positionId uint64) (int64, error) {
	return getImplementation().GetPositionTokensOwed0(positionId)
}

// GetPositionTokensOwed1 returns the token1 amount accrued and owed to a position.
//
// Parameters:
//   - positionId: position NFT token ID whose token1 debt is queried
//
// Returns:
//   - tokensOwed1: token1 amount currently owed to the position
//   - err: non-nil when positionId cannot be resolved
func GetPositionTokensOwed1(positionId uint64) (int64, error) {
	return getImplementation().GetPositionTokensOwed1(positionId)
}

// GetPositionTokensOwed returns the token0 and token1 amounts accrued and owed to a position.
//
// Parameters:
//   - positionId: position NFT token ID whose accrued token debt is queried
//
// Returns:
//   - tokensOwed0: token0 amount currently owed to the position
//   - tokensOwed1: token1 amount currently owed to the position
//   - err: non-nil when positionId cannot be resolved
func GetPositionTokensOwed(positionId uint64) (int64, int64, error) {
	return getImplementation().GetPositionTokensOwed(positionId)
}

// GetUnclaimedFee returns the unclaimed fees for both tokens of a position as decimal strings.
//
// Parameters:
//   - positionId: position NFT token ID whose unclaimed fees are queried
//
// Returns:
//   - fee0: unclaimed token0 fee amount, represented as a decimal string
//   - fee1: unclaimed token1 fee amount, represented as a decimal string
//   - err: non-nil when positionId or the associated pool fee-growth data cannot be resolved
func GetUnclaimedFee(positionId uint64) (string, string, error) {
	fee0, fee1, err := getImplementation().GetUnclaimedFee(positionId)
	if err != nil {
		return "", "", err
	}

	return fee0.ToString(), fee1.ToString(), nil
}

// GetPositionOwner returns the owner address of a position NFT.
//
// Parameters:
//   - positionId: position NFT token ID whose owner is queried
//
// Returns:
//   - owner: address that owns the position NFT
//   - err: non-nil when the NFT owner lookup fails
func GetPositionOwner(positionId uint64) (address, error) {
	return getImplementation().GetPositionOwner(positionId)
}
