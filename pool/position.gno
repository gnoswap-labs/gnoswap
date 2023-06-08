package gnoswap

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

type PositionInfo struct {
	liquidity bigint

	feeGrowthInside0LastX128 bigint
	feeGrowthInside1LastX128 bigint

	tokensOwed0 bigint
	tokensOwed1 bigint
}

func PositionGetKey(
	owner std.Address,
	tickLower bigint,
	tickUpper bigint,
) string {
	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)

	// sum256 := sha256.Sum256([]byte(key))[:]
	// return hex.EncodeToString(sum256)

	encoded := base64.StdEncoding.EncodeToString([]byte(key))
	return encoded
}

func (pool *Pool) PositionUpdateWithKey(
	key string,
	liquidityDelta bigint,
	feeGrowthInside0X128 bigint,
	feeGrowthInside1X128 bigint,
) PositionInfo {
	requireUnsigned(feeGrowthInside0X128, "position.gno__PositionUpdateWithKey__feeGrowthInside0X128")
	requireUnsigned(feeGrowthInside1X128, "position.gno__PositionUpdateWithKey__feeGrowthInside1X128")

	// position := positions[key]
	_position, exists := pool.positions.Get(key)
	var position PositionInfo
	if !exists {
		position = PositionInfo{}
		// panic("position does not exist #2")
	} else {
		position = _position.(PositionInfo)
	}

	p := PositionUpdate(position, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	// positions[key] = p
	pool.positions.Set(key, p)
	return p
}

func PositionUpdate(
	self PositionInfo,
	liquidityDelta bigint,
	feeGrowthInside0X128 bigint,
	feeGrowthInside1X128 bigint,
) PositionInfo {
	requireUnsigned(feeGrowthInside0X128, "position.gno__PositionUpdate__feeGrowthInside0X128")
	requireUnsigned(feeGrowthInside1X128, "position.gno__PositionUpdate__feeGrowthInside1X128")

	var liquidityNext bigint

	if liquidityDelta == 0 {
		require(self.liquidity > 0, "position.gno__PositionUpdate__self.liquidity")
		liquidityNext = self.liquidity
	} else {
		liquidityNext = LiquidityMathAddDelta(self.liquidity, liquidityDelta)
	}

	tokensOwed0 := (feeGrowthInside0X128 - self.feeGrowthInside0LastX128) * self.liquidity / Q128
	tokensOwed1 := (feeGrowthInside1X128 - self.feeGrowthInside1LastX128) * self.liquidity / Q128
	requireUnsigned(tokensOwed0, "position.gno__PositionUpdate__tokensOwed0")
	requireUnsigned(tokensOwed1, "position.gno__PositionUpdate__tokensOwed1")

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
