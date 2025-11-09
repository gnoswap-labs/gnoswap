package v1

import (
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
