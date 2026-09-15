package position

import (
	"errors"

	"gno.land/p/gnoswap/consts/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"
	rotree "gno.land/p/nt/bptree/rotree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// getPosition returns a position for a given position ID.
// Returns an error if the position doesn't exist.
func (p *positionV1) getPosition(positionId uint64) (position.Position, error) {
	pos, exists := p.store.GetPosition(positionId)
	if !exists {
		return pos, errors.New(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return pos, nil
}

// mustGetPosition returns a position for a given position ID.
// panics if position doesn't exist
func (p *positionV1) mustGetPosition(positionId uint64) *position.Position {
	position, err := p.getPosition(positionId)
	if err != nil {
		panic(err.Error())
	}

	return &position
}

// GetPositions returns a read-only view of every position, keyed by the decimal
// string form of the position ID.
//
// Returns:
//   - positions: read-only tree exposing the position store without mutation methods
func (p *positionV1) GetPositions() *rotree.ReadOnlyTree {
	// makeEntrySafeFn is a function that makes an entry safe to read.
	// But Position is immutable, so we can just return the entry as is.
	return rotree.Wrap(p.store.GetPositions(), nil)
}

// ExistPosition reports whether a position exists for a given position ID.
//
// Parameters:
//   - positionId: numeric ID to test in the position store
//
// Returns:
//   - exists: true when the position store contains positionId
func (p *positionV1) ExistPosition(positionId uint64) bool {
	return p.store.HasPosition(positionId)
}

// IsBurned reports the empty-position marker stored for a position.
//
// Parameters:
//   - positionId: numeric ID whose burned marker is requested
//
// Returns:
//   - burned: true when the position is marked empty; the NFT record itself may still exist
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) IsBurned(positionId uint64) (bool, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return false, err
	}

	return position.Burned(), nil
}

// IsInRange reports whether the pool's current tick is inside a position's range.
//
// Parameters:
//   - positionId: numeric ID whose tick range and pool are inspected
//
// Returns:
//   - inRange: true when tickLower <= current pool tick < tickUpper
//   - err: nil on success; an error when the position or its pool tick cannot be read
func (p *positionV1) IsInRange(positionId uint64) (bool, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return false, err
	}

	poolPath := position.PoolKey()
	poolCurrentTick, err := pl.GetSlot0Tick(poolPath)
	if err != nil {
		return false, err
	}

	return position.TickLower() <= poolCurrentTick && poolCurrentTick < position.TickUpper(), nil
}

// GetPositionOperator returns the address approved to operate on a position.
//
// Parameters:
//   - positionId: numeric ID whose operator is requested
//
// Returns:
//   - operator: approved operator address, or the empty address when none is set
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionOperator(positionId uint64) (address, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return address(""), err
	}

	return position.Operator(), nil
}

// GetPositionPoolKey returns the pool identifier stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose pool key is requested
//
// Returns:
//   - poolKey: pool key encoding the position's token pair and fee tier
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionPoolKey(positionId uint64) (string, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return "", err
	}

	return position.PoolKey(), nil
}

// GetPositionTickLower returns the lower tick boundary stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose lower tick is requested
//
// Returns:
//   - tickLower: lower tick boundary, inclusive in range checks
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionTickLower(positionId uint64) (int32, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, err
	}

	return position.TickLower(), nil
}

// GetPositionTickUpper returns the upper tick boundary stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose upper tick is requested
//
// Returns:
//   - tickUpper: upper tick boundary, exclusive in range checks
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionTickUpper(positionId uint64) (int32, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, err
	}

	return position.TickUpper(), nil
}

// GetPositionLiquidity returns the decimal-encoded liquidity stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose liquidity is requested
//
// Returns:
//   - liquidity: decimal string representing the position's current liquidity
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionLiquidity(positionId uint64) (string, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return "", err
	}

	return position.Liquidity(), nil
}

// GetPositionTokenBalances returns balances derived from current pool price,
// position range, and liquidity; token balances are not stored snapshots.
//
// Parameters:
//   - positionId: numeric ID whose current token balances are calculated
//
// Returns:
//   - token0Balance: current token0 amount represented by the position's liquidity and range
//   - token1Balance: current token1 amount represented by the position's liquidity and range
//   - err: nil when the position exists; errPositionDoesNotExist when it is absent (pool price lookup failures panic during calculation)
func (p *positionV1) GetPositionTokenBalances(positionId uint64) (int64, int64, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, 0, err
	}

	balance0, balance1 := calculatePositionBalances(&position)
	return balance0, balance1, nil
}

// GetPositionFeeGrowthInside0LastX128 returns the token0 fee-growth checkpoint
// stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose token0 fee-growth checkpoint is requested
//
// Returns:
//   - feeGrowthInside0LastX128: decimal-encoded Q128 token0 fee growth inside the position's range at its last update
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionFeeGrowthInside0LastX128(positionId uint64) (string, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return "", err
	}

	return position.FeeGrowthInside0LastX128(), nil
}

// GetPositionFeeGrowthInside1LastX128 returns the token1 fee-growth checkpoint
// stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose token1 fee-growth checkpoint is requested
//
// Returns:
//   - feeGrowthInside1LastX128: decimal-encoded Q128 token1 fee growth inside the position's range at its last update
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionFeeGrowthInside1LastX128(positionId uint64) (string, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return "", err
	}

	return position.FeeGrowthInside1LastX128(), nil
}

// GetPositionFeeGrowthInsideLastX128 returns both fee-growth checkpoints stored
// on a position, in token0 then token1 order.
//
// Parameters:
//   - positionId: numeric ID whose fee-growth checkpoints are requested
//
// Returns:
//   - feeGrowthInside0LastX128: decimal-encoded Q128 token0 fee growth checkpoint
//   - feeGrowthInside1LastX128: decimal-encoded Q128 token1 fee growth checkpoint
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionFeeGrowthInsideLastX128(positionId uint64) (string, string, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return "", "", err
	}

	return position.FeeGrowthInside0LastX128(), position.FeeGrowthInside1LastX128(), nil
}

// GetPositionTicks returns both tick boundaries stored on a position.
//
// Parameters:
//   - positionId: numeric ID whose tick boundaries are requested
//
// Returns:
//   - tickLower: lower tick boundary, inclusive in range checks
//   - tickUpper: upper tick boundary, exclusive in range checks
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionTicks(positionId uint64) (int32, int32, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, 0, err
	}

	return position.TickLower(), position.TickUpper(), nil
}

// GetPositionTokensOwed0 returns the stored token0 amount owed to a position.
//
// Parameters:
//   - positionId: numeric ID whose token0 owed amount is requested
//
// Returns:
//   - tokensOwed0: accrued token0 amount awaiting collection, in token units
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionTokensOwed0(positionId uint64) (int64, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, err
	}

	return position.TokensOwed0(), nil
}

// GetPositionTokensOwed1 returns the stored token1 amount owed to a position.
//
// Parameters:
//   - positionId: numeric ID whose token1 owed amount is requested
//
// Returns:
//   - tokensOwed1: accrued token1 amount awaiting collection, in token units
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionTokensOwed1(positionId uint64) (int64, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, err
	}

	return position.TokensOwed1(), nil
}

// GetPositionTokensOwed returns both stored token amounts owed to a position,
// in token0 then token1 order.
//
// Parameters:
//   - positionId: numeric ID whose owed amounts are requested
//
// Returns:
//   - tokensOwed0: accrued token0 amount awaiting collection, in token units
//   - tokensOwed1: accrued token1 amount awaiting collection, in token units
//   - err: nil on lookup success; errPositionDoesNotExist when the position is absent
func (p *positionV1) GetPositionTokensOwed(positionId uint64) (int64, int64, error) {
	position, err := p.getPosition(positionId)
	if err != nil {
		return 0, 0, err
	}

	return position.TokensOwed0(), position.TokensOwed1(), nil
}

// GetPositionOwner returns the address that owns the position NFT.
//
// Parameters:
//   - positionId: numeric ID whose NFT ownership is requested
//
// Returns:
//   - owner: current owner address reported by the NFT accessor
//   - err: nil when the NFT accessor finds the token; otherwise its ownership lookup error
func (p *positionV1) GetPositionOwner(positionId uint64) (address, error) {
	owner, err := p.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		return address(""), err
	}

	return owner, nil
}

// GetUnclaimedFee calculates unclaimed token fees from current in-range
// fee growth, the position's checkpoints, and its liquidity.
//
// Parameters:
//   - positionId: numeric ID whose unclaimed token fees are calculated
//
// Returns:
//   - unclaimedFee0: token0 fees accrued since the stored checkpoint, scaled by position liquidity
//   - unclaimedFee1: token1 fees accrued since the stored checkpoint, scaled by position liquidity
//   - err: nil on success; nil fee pointers and the underlying lookup error when position or pool data is unavailable
func (p *positionV1) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint, error) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees
	position, err := p.getPosition(positionId)
	if err != nil {
		return nil, nil, err
	}

	liquidity := u256.MustFromDecimal(position.Liquidity())
	tickLower := position.TickLower()
	tickUpper := position.TickUpper()

	poolKey := position.PoolKey()

	currentTick, err := pl.GetSlot0Tick(poolKey)
	if err != nil {
		return nil, nil, err
	}

	feeGrowthGlobal0X128Str, feeGrowthGlobal1X128Str, err := pl.GetFeeGrowthGlobalX128(poolKey)
	if err != nil {
		return nil, nil, err
	}
	feeGrowthGlobal0X128 := u256.MustFromDecimal(feeGrowthGlobal0X128Str)
	feeGrowthGlobal1X128 := u256.MustFromDecimal(feeGrowthGlobal1X128Str)

	tickUpperFeeGrowthOutside0X128Str, tickUpperFeeGrowthOutside1X128Str, err := pl.GetTickFeeGrowthOutsideX128(poolKey, tickUpper)
	if err != nil {
		return nil, nil, err
	}
	tickUpperFeeGrowthOutside0X128 := u256.MustFromDecimal(tickUpperFeeGrowthOutside0X128Str)
	tickUpperFeeGrowthOutside1X128 := u256.MustFromDecimal(tickUpperFeeGrowthOutside1X128Str)

	tickLowerFeeGrowthOutside0X128Str, tickLowerFeeGrowthOutside1X128Str, err := pl.GetTickFeeGrowthOutsideX128(poolKey, tickLower)
	if err != nil {
		return nil, nil, err
	}
	tickLowerFeeGrowthOutside0X128 := u256.MustFromDecimal(tickLowerFeeGrowthOutside0X128Str)
	tickLowerFeeGrowthOutside1X128 := u256.MustFromDecimal(tickLowerFeeGrowthOutside1X128Str)

	feeGrowthInside0LastX128 := u256.MustFromDecimal(position.FeeGrowthInside0LastX128())
	feeGrowthInside1LastX128 := u256.MustFromDecimal(position.FeeGrowthInside1LastX128())

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 *u256.Uint

	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = u256.Zero().Sub(feeGrowthGlobal0X128, tickUpperFeeGrowthOutside0X128)
		tickUpperFeeGrowthAbove1 = u256.Zero().Sub(feeGrowthGlobal1X128, tickUpperFeeGrowthOutside1X128)
	} else {
		tickUpperFeeGrowthAbove0 = tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = tickUpperFeeGrowthOutside1X128
	}

	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = tickLowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = u256.Zero().Sub(feeGrowthGlobal0X128, tickLowerFeeGrowthOutside0X128)
		tickLowerFeeGrowthBelow1 = u256.Zero().Sub(feeGrowthGlobal1X128, tickLowerFeeGrowthOutside1X128)
	}

	feeGrowthInside0X128 := u256.Zero().Sub(feeGrowthGlobal0X128, tickLowerFeeGrowthBelow0)
	feeGrowthInside0X128 = u256.Zero().Sub(feeGrowthInside0X128, tickUpperFeeGrowthAbove0)

	feeGrowthInside1X128 := u256.Zero().Sub(feeGrowthGlobal1X128, tickLowerFeeGrowthBelow1)
	feeGrowthInside1X128 = u256.Zero().Sub(feeGrowthInside1X128, tickUpperFeeGrowthAbove1)

	diffGrowthInside0X128 := u256.Zero().Sub(feeGrowthInside0X128, feeGrowthInside0LastX128)
	unclaimedFee0 := u256.MulDiv(diffGrowthInside0X128, liquidity, consts.Q128())

	diffGrowthInside1X128 := u256.Zero().Sub(feeGrowthInside1X128, feeGrowthInside1LastX128)
	unclaimedFee1 := u256.MulDiv(diffGrowthInside1X128, liquidity, consts.Q128())
	return unclaimedFee0, unclaimedFee1, nil
}
