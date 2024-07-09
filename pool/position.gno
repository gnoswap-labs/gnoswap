package pool

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
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
	// PARAM INIT
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthInside0X128 = feeGrowthInside0X128.NilToZero()
	feeGrowthInside1X128 = feeGrowthInside1X128.NilToZero()

	positionToUpdate := pool.positions[positionKey]
	positionAfterUpdate := positionUpdate(positionToUpdate, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	pool.positions[positionKey] = positionAfterUpdate

	return positionAfterUpdate
}

func positionUpdate(
	self PositionInfo,
	liquidityDelta *i256.Int, // int128
	feeGrowthInside0X128 *u256.Uint, // uint256
	feeGrowthInside1X128 *u256.Uint, // uint256
) PositionInfo {
	self.init()

	var liquidityNext *u256.Uint
	if liquidityDelta.IsZero() {
		liquidityNext = self.liquidity
	} else {
		liquidityNext = liquidityMathAddDelta(self.liquidity, liquidityDelta)
	}

	tokensOwed0 := u256.Zero()
	{
		diff := new(u256.Uint).Sub(feeGrowthInside0X128, self.feeGrowthInside0LastX128)
		tokensOwed0 = u256.MulDiv(diff, self.liquidity, u256.MustFromDecimal(consts.Q128))
	}

	tokensOwed1 := u256.Zero()
	{
		diff := new(u256.Uint).Sub(feeGrowthInside1X128, self.feeGrowthInside1LastX128)
		tokensOwed1 = u256.MulDiv(diff, self.liquidity, u256.MustFromDecimal(consts.Q128))
	}

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
