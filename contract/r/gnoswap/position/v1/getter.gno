package position

import (
	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	ufmt "gno.land/p/nt/ufmt/v0"

	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// MustGetPosition returns a position for a given position ID.
// panics if position doesn't exist
func (p *positionV1) mustGetPosition(positionId uint64) *position.Position {
	pos, exist := p.store.GetPosition(positionId)
	if !exist {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return &pos
}

// GetPositions returns a read-only view of every position, keyed by the decimal
// string form of the position ID.
func (p *positionV1) GetPositions() *rotree.ReadOnlyTree {
	// makeEntrySafeFn is a function that makes an entry safe to read.
	// But Position is immutable, so we can just return the entry as is.
	return rotree.Wrap(p.store.GetPositions(), nil)
}

// ExistPosition checks if a position exists for a given position ID
func (p *positionV1) ExistPosition(positionId uint64) bool {
	return p.store.HasPosition(positionId)
}

func (p *positionV1) IsBurned(positionId uint64) (bool, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return false, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.Burned(), nil
}

func (p *positionV1) IsInRange(positionId uint64) (bool, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return false, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	poolPath := position.PoolKey()
	poolCurrentTick, err := pl.GetSlot0Tick(poolPath)
	if err != nil {
		return false, err
	}

	return position.TickLower() <= poolCurrentTick && poolCurrentTick < position.TickUpper(), nil
}

func (p *positionV1) GetPositionOperator(positionId uint64) (address, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return address(""), ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.Operator(), nil
}

func (p *positionV1) GetPositionPoolKey(positionId uint64) (string, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return "", ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.PoolKey(), nil
}

func (p *positionV1) GetPositionTickLower(positionId uint64) (int32, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return 0, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.TickLower(), nil
}

func (p *positionV1) GetPositionTickUpper(positionId uint64) (int32, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return 0, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.TickUpper(), nil
}

func (p *positionV1) GetPositionLiquidity(positionId uint64) (string, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return "", ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.Liquidity(), nil
}

func (p *positionV1) GetPositionTokenBalances(positionId uint64) (int64, int64, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return 0, 0, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	balance0, balance1 := calculatePositionBalances(&position)
	return balance0, balance1, nil
}

func (p *positionV1) GetPositionFeeGrowthInside0LastX128(positionId uint64) (string, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return "", ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.FeeGrowthInside0LastX128(), nil
}

func (p *positionV1) GetPositionFeeGrowthInside1LastX128(positionId uint64) (string, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return "", ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.FeeGrowthInside1LastX128(), nil
}

func (p *positionV1) GetPositionTokensOwed0(positionId uint64) (int64, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return 0, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.TokensOwed0(), nil
}

func (p *positionV1) GetPositionTokensOwed1(positionId uint64) (int64, error) {
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return 0, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return position.TokensOwed1(), nil
}

func (p *positionV1) GetPositionOwner(positionId uint64) (address, error) {
	owner, err := p.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		return address(""), err
	}

	return owner, nil
}

func (p *positionV1) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint, error) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees
	position, exists := p.store.GetPosition(positionId)
	if !exists {
		return nil, nil, ufmt.Errorf("%s", newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
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
