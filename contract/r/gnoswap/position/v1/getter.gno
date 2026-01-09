package v1

import (
	"strconv"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt"

	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// MustGetPosition returns a position for a given position ID.
// panics if position doesn't exist
func (p *positionV1) mustGetPosition(positionId uint64) *position.Position {
	pos, exist := p.GetPosition(positionId)
	if !exist {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}

	return &pos
}

// GetPositionCount returns the total number of positions.
func (p *positionV1) GetPositionCount() int {
	return p.store.GetPositions().Size()
}

// GetPositionIDs returns a paginated list of position IDs.
func (p *positionV1) GetPositionIDs(offset, count int) []uint64 {
	positions := p.store.GetPositions()
	positionIDs := make([]uint64, 0)

	positions.IterateByOffset(offset, count, func(key string, _ any) bool {
		id, err := strconv.ParseUint(key, 10, 64)
		if err != nil {
			return false
		}

		positionIDs = append(positionIDs, id)

		return false
	})

	return positionIDs
}

// GetPosition returns a position for a given position ID.
// Returns false if position doesn't exist
func (p *positionV1) GetPosition(id uint64) (position.Position, bool) {
	return p.store.GetPosition(id)
}

// ExistPosition checks if a position exists for a given position ID
func (p *positionV1) ExistPosition(positionId uint64) bool {
	return p.store.HasPosition(positionId)
}

func (p *positionV1) IsBurned(positionId uint64) bool {
	return p.mustGetPosition(positionId).Burned()
}

func (p *positionV1) IsInRange(positionId uint64) bool {
	position := p.mustGetPosition(positionId)
	poolPath := position.PoolKey()
	poolCurrentTick := pl.GetSlot0Tick(poolPath)

	return position.TickLower() <= poolCurrentTick && poolCurrentTick < position.TickUpper()
}

func (p *positionV1) GetPositionOperator(positionId uint64) address {
	return p.mustGetPosition(positionId).Operator()
}

func (p *positionV1) GetPositionPoolKey(positionId uint64) string {
	return p.mustGetPosition(positionId).PoolKey()
}

func (p *positionV1) GetPositionTickLower(positionId uint64) int32 {
	return p.mustGetPosition(positionId).TickLower()
}

func (p *positionV1) GetPositionTickUpper(positionId uint64) int32 {
	return p.mustGetPosition(positionId).TickUpper()
}

func (p *positionV1) GetPositionLiquidity(positionId uint64) *u256.Uint {
	return p.mustGetPosition(positionId).Liquidity()
}

func (p *positionV1) GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	return p.mustGetPosition(positionId).FeeGrowthInside0LastX128()
}

func (p *positionV1) GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	return p.mustGetPosition(positionId).FeeGrowthInside1LastX128()
}

func (p *positionV1) GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	return p.mustGetPosition(positionId).TokensOwed0()
}

func (p *positionV1) GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	return p.mustGetPosition(positionId).TokensOwed1()
}

func (p *positionV1) GetPositionOwner(positionId uint64) address {
	owner, err := p.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		panic(newErrorWithDetail(
			errDataNotFound, err.Error()))
	}

	return owner
}

func (p *positionV1) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees
	position := p.mustGetPosition(positionId)

	liquidity := position.Liquidity()
	tickLower := position.TickLower()
	tickUpper := position.TickUpper()

	poolKey := position.PoolKey()

	currentTick := pl.GetSlot0Tick(poolKey)

	feeGrowthGlobal0X128, feeGrowthGlobal1X128 := pl.GetFeeGrowthGlobalX128(poolKey)
	tickUpperFeeGrowthOutside0X128, tickUpperFeeGrowthOutside1X128 := pl.GetTickFeeGrowthOutsideX128(poolKey, tickUpper)
	tickLowerFeeGrowthOutside0X128, tickLowerFeeGrowthOutside1X128 := pl.GetTickFeeGrowthOutsideX128(poolKey, tickLower)

	feeGrowthInside0LastX128 := position.FeeGrowthInside0LastX128()
	feeGrowthInside1LastX128 := position.FeeGrowthInside1LastX128()

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 *u256.Uint

	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = subUint256(feeGrowthGlobal0X128, tickUpperFeeGrowthOutside0X128)
		tickUpperFeeGrowthAbove1 = subUint256(feeGrowthGlobal1X128, tickUpperFeeGrowthOutside1X128)
	} else {
		tickUpperFeeGrowthAbove0 = tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = tickUpperFeeGrowthOutside1X128
	}

	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = tickLowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = subUint256(feeGrowthGlobal0X128, tickLowerFeeGrowthOutside0X128)
		tickLowerFeeGrowthBelow1 = subUint256(feeGrowthGlobal1X128, tickLowerFeeGrowthOutside1X128)
	}

	feeGrowthInside0X128 := subUint256(feeGrowthGlobal0X128, tickLowerFeeGrowthBelow0)
	feeGrowthInside0X128 = subUint256(feeGrowthInside0X128, tickUpperFeeGrowthAbove0)

	feeGrowthInside1X128 := subUint256(feeGrowthGlobal1X128, tickLowerFeeGrowthBelow1)
	feeGrowthInside1X128 = subUint256(feeGrowthInside1X128, tickUpperFeeGrowthAbove1)

	diffGrowthInside0X128 := subUint256(feeGrowthInside0X128, feeGrowthInside0LastX128)
	unclaimedFee0X128, overflow := u256.Zero().MulOverflow(liquidity, diffGrowthInside0X128)
	if overflow {
		panic(errOverflow)
	}
	unclaimedFee0 := u256.Zero().Div(unclaimedFee0X128, q128)

	diffGrowthInside1X128 := subUint256(feeGrowthInside1X128, feeGrowthInside1LastX128)
	unclaimedFee1X128, overflow := u256.Zero().MulOverflow(liquidity, diffGrowthInside1X128)
	if overflow {
		panic(errOverflow)
	}

	return unclaimedFee0, u256.Zero().Div(unclaimedFee1X128, q128)
}
