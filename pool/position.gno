package pool

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	Q128 = u256.MustFromDecimal(consts.Q128)
)

// positionGetKey generates a unique key for a position based on the owner's address and the tick range.
func positionGetKey(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
) string {
	if !owner.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			ufmt.Sprintf("position.gno__positionGetKey() || invalid owner address %s", owner.String()),
		))
	}

	if tickLower > tickUpper {
		panic(addDetailToError(
			errInvalidTickRange,
			ufmt.Sprintf("position.gno__positionGetKey() || tickLower(%d) is greater than tickUpper(%d)", tickLower, tickUpper),
		))
	}

	positionKey := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(positionKey))
	return encoded
}

// positionUpdateWithKey updates a position in the pool and returns the updated position.
func (pool *Pool) positionUpdateWithKey(
	positionKey string,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) PositionInfo {
	// if pointer is nil, set to zero for calculation
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthInside0X128 = feeGrowthInside0X128.NilToZero()
	feeGrowthInside1X128 = feeGrowthInside1X128.NilToZero()

	positionToUpdate := pool.positions[positionKey]
	positionAfterUpdate := positionUpdate(positionToUpdate, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	pool.positions[positionKey] = positionAfterUpdate

	return positionAfterUpdate
}

// positionUpdate calculates and returns an updated PositionInfo.
func positionUpdate(
	position PositionInfo,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) PositionInfo {
	position.init()

	var liquidityNext *u256.Uint
	if liquidityDelta.IsZero() {
		if position.liquidity.IsZero() {
			panic(addDetailToError(
				errZeroLiquidity,
				"position.gno__positionUpdate() || both liquidityDelta and current position's liquidity are zero",
			))
		}

		liquidityNext = position.liquidity
	} else {
		liquidityNext = liquidityMathAddDelta(position.liquidity, liquidityDelta)
	}

	tokensOwed0 := u256.Zero()
	diff0 := new(u256.Uint).Sub(feeGrowthInside0X128, position.feeGrowthInside0LastX128)
	tokensOwed0 = u256.MulDiv(diff0, position.liquidity, Q128)

	tokensOwed1 := u256.Zero()
	diff1 := new(u256.Uint).Sub(feeGrowthInside1X128, position.feeGrowthInside1LastX128)
	tokensOwed1 = u256.MulDiv(diff1, position.liquidity, Q128)

	if !(liquidityDelta.IsZero()) {
		position.liquidity = liquidityNext
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0X128
	position.feeGrowthInside1LastX128 = feeGrowthInside1X128
	if tokensOwed0.Gt(u256.Zero()) || tokensOwed1.Gt(u256.Zero()) {
		position.tokensOwed0 = position.tokensOwed0.Add(position.tokensOwed0, tokensOwed0)
		position.tokensOwed1 = position.tokensOwed1.Add(position.tokensOwed1, tokensOwed1)
	}

	return position
}

// receiver getters

func (p *Pool) GetPositionLiquidity(key string) *u256.Uint {
	return p.mustGetPosition(key).liquidity
}

func (p *Pool) GetPositionFeeGrowthInside0LastX128(key string) *u256.Uint {
	return p.mustGetPosition(key).feeGrowthInside0LastX128
}

func (p *Pool) GetPositionFeeGrowthInside1LastX128(key string) *u256.Uint {
	return p.mustGetPosition(key).feeGrowthInside1LastX128
}

func (p *Pool) GetPositionTokensOwed0(key string) *u256.Uint {
	return p.mustGetPosition(key).tokensOwed0
}

func (p *Pool) GetPositionTokensOwed1(key string) *u256.Uint {
	return p.mustGetPosition(key).tokensOwed1
}

func (p *Pool) mustGetPosition(key string) PositionInfo {
	position, exist := p.positions[key]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("position(%s) does not exist", key),
		))
	}

	return position
}
