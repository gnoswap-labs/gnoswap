package pool

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"
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
	liquidityDelta *i256.Int, // int128
	feeGrowthInside0X128 *u256.Uint, // uint256
	feeGrowthInside1X128 *u256.Uint, // uint256
) PositionInfo {
	// START INIT PARAM
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthInside0X128 = feeGrowthInside0X128.NilToZero()
	feeGrowthInside1X128 = feeGrowthInside1X128.NilToZero()
	// END INIT PARAM

	position := pool.positions[positionKey]

	p := positionUpdate(position, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	pool.positions[positionKey] = p

	return p
}

func positionUpdate(
	self PositionInfo,
	liquidityDelta *i256.Int, // int128
	feeGrowthInside0X128 *u256.Uint, // uint256
	feeGrowthInside1X128 *u256.Uint, // uint256
) PositionInfo {
	// START INIT PARAM
	self.liquidity = self.liquidity.NilToZero()
	self.feeGrowthInside0LastX128 = self.feeGrowthInside0LastX128.NilToZero()
	self.feeGrowthInside1LastX128 = self.feeGrowthInside1LastX128.NilToZero()
	self.tokensOwed0 = self.tokensOwed0.NilToZero()
	self.tokensOwed1 = self.tokensOwed1.NilToZero()

	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthInside0X128 = feeGrowthInside0X128.NilToZero()
	feeGrowthInside1X128 = feeGrowthInside1X128.NilToZero()
	// END INIT PARAM

	var liquidityNext *u256.Uint
	if liquidityDelta.IsZero() {
		liquidityNext = self.liquidity
	} else {
		liquidityNext = liquidityMathAddDelta(self.liquidity, liquidityDelta)
	}

	tokensOwed0 := new(u256.Uint).Sub(feeGrowthInside0X128, self.feeGrowthInside0LastX128)
	tokensOwed0 = tokensOwed0.Mul(tokensOwed0, self.liquidity)
	tokensOwed0 = tokensOwed0.Div(tokensOwed0, u256.MustFromDecimal(consts.Q128))

	tokensOwed1 := new(u256.Uint).Sub(feeGrowthInside1X128, self.feeGrowthInside1LastX128)
	tokensOwed1 = tokensOwed1.Mul(tokensOwed1, self.liquidity)
	tokensOwed1 = tokensOwed1.Div(tokensOwed1, u256.MustFromDecimal(consts.Q128))

	if !(liquidityDelta.IsZero()) {
		self.liquidity = liquidityNext
	}

	self.feeGrowthInside0LastX128 = feeGrowthInside0X128
	self.feeGrowthInside1LastX128 = feeGrowthInside1X128
	if tokensOwed0.Gt(u256.Zero()) || tokensOwed1.Gt(u256.Zero()) {
		self.tokensOwed0 = self.tokensOwed0.Add(self.tokensOwed0, tokensOwed0)
		self.tokensOwed1 = self.tokensOwed1.Add(self.tokensOwed1, tokensOwed1)
	}

	return self
}
