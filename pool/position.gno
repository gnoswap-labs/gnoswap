package pool

import (
	"encoding/base64"
	"std"

	"gno.land/p/demo/ufmt"
)

func positionGetKey(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}

func (pool *Pool) positionUpdateWithKey(
	key string,
	liquidityDelta bigint,
	feeGrowthInside0X128 bigint,
	feeGrowthInside1X128 bigint,
) PositionInfo {
	requireUnsigned(feeGrowthInside0X128, ufmt.Sprintf("[POOL] position.gno__positionUpdateWithKey() || feeGrowthInside0X128(%d) >= 0", feeGrowthInside0X128))
	requireUnsigned(feeGrowthInside1X128, ufmt.Sprintf("[POOL] position.gno__positionUpdateWithKey() || feeGrowthInside1X128(%d) >= 0", feeGrowthInside1X128))

	position := pool.positions[key]

	p := positionUpdate(position, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	pool.positions[key] = p

	return p
}

func positionUpdate(
	self PositionInfo,
	liquidityDelta bigint,
	feeGrowthInside0X128 bigint,
	feeGrowthInside1X128 bigint,
) PositionInfo {
	requireUnsigned(feeGrowthInside0X128, ufmt.Sprintf("[POOL] position.gno__positionUpdate() || feeGrowthInside0X128(%d) >= 0", feeGrowthInside0X128))
	requireUnsigned(feeGrowthInside1X128, ufmt.Sprintf("[POOL] position.gno__positionUpdate() || feeGrowthInside1X128(%d) >= 0", feeGrowthInside1X128))

	var liquidityNext bigint
	if liquidityDelta == 0 {
		liquidityNext = self.liquidity
	} else {
		liquidityNext = liquidityMathAddDelta(self.liquidity, liquidityDelta)
	}

	tokensOwed0 := (feeGrowthInside0X128 - self.feeGrowthInside0LastX128) * self.liquidity / Q128
	tokensOwed1 := (feeGrowthInside1X128 - self.feeGrowthInside1LastX128) * self.liquidity / Q128

	requireUnsigned(tokensOwed0, ufmt.Sprintf("[POOL] position.gno__positionUpdate() || tokensOwed0(%d) >= 0", tokensOwed0))
	requireUnsigned(tokensOwed1, ufmt.Sprintf("[POOL] position.gno__positionUpdate() || tokensOwed1(%d) >= 0", tokensOwed1))

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
