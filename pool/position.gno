package pool

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

func positionGetKey(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
) string {
	positionKey := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(positionKey))
	return encoded
}

func (pool *Pool) positionUpdateWithKey(
	positionKey string,
	liquidityDelta *u256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) PositionInfo {

	position := pool.positions[positionKey]

	p := positionUpdate(position, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	pool.positions[positionKey] = p

	return p
}

func positionUpdate(
	self PositionInfo,
	liquidityDelta *u256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) PositionInfo {
	liquidityNext := u256.NewInt(0)

	// check nil
	self.liquidity = self.liquidity.NilToZero()
	self.feeGrowthInside0LastX128 = self.feeGrowthInside0LastX128.NilToZero()
	self.feeGrowthInside1LastX128 = self.feeGrowthInside1LastX128.NilToZero()
	self.tokensOwed0 = self.tokensOwed0.NilToZero()
	self.tokensOwed1 = self.tokensOwed1.NilToZero()
	//

	if liquidityDelta.IsZero() {
		liquidityNext = self.liquidity.Int()
	} else {
		liquidityNext = liquidityMathAddDelta(self.liquidity, liquidityDelta).Int()
	}

	tokensOwed0 := new(u256.Uint).Sub(feeGrowthInside0X128, self.feeGrowthInside0LastX128)
	tokensOwed0 = tokensOwed0.Mul(tokensOwed0, self.liquidity)
	tokensOwed0 = tokensOwed0.Div(tokensOwed0, u256.FromBigint(consts.Q128))

	tokensOwed1 := new(u256.Uint).Sub(feeGrowthInside1X128, self.feeGrowthInside1LastX128)
	tokensOwed1 = tokensOwed1.Mul(tokensOwed1, self.liquidity)
	tokensOwed1 = tokensOwed1.Div(tokensOwed1, u256.FromBigint(consts.Q128))

	if !liquidityDelta.IsZero() {
		self.liquidity = liquidityNext.Uint()
	}

	self.feeGrowthInside0LastX128 = feeGrowthInside0X128
	self.feeGrowthInside1LastX128 = feeGrowthInside1X128
	self.tokensOwed0.Add(self.tokensOwed0, tokensOwed0)
	self.tokensOwed1.Add(self.tokensOwed1, tokensOwed1)

	return self
}
