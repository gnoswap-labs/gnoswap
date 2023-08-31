package gnoswap

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
)

func PositionGetKey(
	owner std.Address,
	tickLower bigint,
	tickUpper bigint,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded

	// sum256 := sha256.Sum256([]byte(key))[:]
	// return hex.EncodeToString(sum256)
}

func (pool *Pool) PositionUpdateWithKey(
	key string,
	liquidityDelta bigint,
	feeGrowthInside0X128 bigint,
	feeGrowthInside1X128 bigint,
) PositionInfo {
	requireUnsigned(feeGrowthInside0X128, ufmt.Sprintf("[POOL] position.gno__PositionUpdateWithKey() || feeGrowthInside0X128(%s) >= 0", feeGrowthInside0X128))
	requireUnsigned(feeGrowthInside1X128, ufmt.Sprintf("[POOL] position.gno__PositionUpdateWithKey() || feeGrowthInside1X128(%s) >= 0", feeGrowthInside1X128))

	position := pool.positions[key]

	p := PositionUpdate(position, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	pool.positions[key] = p

	return p
}

func PositionUpdate(
	self PositionInfo,
	liquidityDelta bigint,
	feeGrowthInside0X128 bigint,
	feeGrowthInside1X128 bigint,
) PositionInfo {
	requireUnsigned(feeGrowthInside0X128, ufmt.Sprintf("[POOL] position.gno__PositionUpdate() || feeGrowthInside0X128(%s) >= 0", feeGrowthInside0X128))
	requireUnsigned(feeGrowthInside1X128, ufmt.Sprintf("[POOL] position.gno__PositionUpdate() || feeGrowthInside1X128(%s) >= 0", feeGrowthInside1X128))

	var liquidityNext bigint

	if liquidityDelta == 0 {
		require(self.liquidity > 0, ufmt.Sprintf("[POOL] position.gno__PositionUpdate() || self.liquidity(%s)", self.liquidity))
		liquidityNext = self.liquidity
	} else {
		liquidityNext = LiquidityMathAddDelta(self.liquidity, liquidityDelta)
	}

	tokensOwed0 := (feeGrowthInside0X128 - self.feeGrowthInside0LastX128) * self.liquidity / Q128
	tokensOwed1 := (feeGrowthInside1X128 - self.feeGrowthInside1LastX128) * self.liquidity / Q128

	requireUnsigned(tokensOwed0, ufmt.Sprintf("[POOL] position.gno__PositionUpdate() || tokensOwed0(%s) >= 0", tokensOwed0))
	requireUnsigned(tokensOwed1, ufmt.Sprintf("[POOL] position.gno__PositionUpdate() || tokensOwed1(%s) >= 0", tokensOwed1))

	if liquidityDelta != 0 {
		self.liquidity = liquidityNext
	}

	self.feeGrowthInside0LastX128 = feeGrowthInside0X128
	self.feeGrowthInside1LastX128 = feeGrowthInside1X128
	if tokensOwed0 > 0 || tokensOwed1 > 0 {
		self.tokensOwed0 += tokensOwed0
		self.tokensOwed1 += tokensOwed1
	}

	return self
}
