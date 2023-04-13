package gnoswap

import (
	"std"
	"crypto/sha256"
	"encoding/hex"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)


// info stored for each user's position
type PositionInfo struct {
	liquidity bigint

	feeGrowthInside0Last bigint
	feeGrowthInside1Last bigint

	tokensOwed0 bigint
	tokensOwed1 bigint
}


func PositionGeyKey(
	owner std.Address,
	tickLower bigint,
	tickUpper bigint,
) (string) {
	// position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];

	// if positions == nil || len(positions) == 0 || positions[key] == nil {
	// 	return PositionInfo{}
	// } else {
	// 	return positions[key]
	// }
	// sum := sha3.Sum256([]byte(key))[:]

	key := ufmt.Sprintf("%s__%d__%d", owner.String(), tickLower, tickUpper)
	sum256 := sha256.Sum256([]byte(key))[:]

	return hex.EncodeToString(sum256)
}

func PositionUpdateWithKey(
	key string,
	liquidityDelta bigint,
	feeGrowthInside0 bigint,
	feeGrowthInside1 bigint,
) (PositionInfo) {
	position, _ := positions[key]
	p := PositionUpdate(position, liquidityDelta, feeGrowthInside0, feeGrowthInside1)
	positions[key] = p
	return p
}

func PositionUpdate(
	self PositionInfo,
	liquidityDelta bigint,
	feeGrowthInside0 bigint,
	feeGrowthInside1 bigint,
) (PositionInfo) {
	// var self PositionInfo = positions[key]
	var liquidityNext bigint

	if (liquidityDelta == 0) {
		require(self.liquidity > 0, "[X] NP")
		liquidityNext = self.liquidity
	} else {
		liquidityNext = LiquidityMathAddDelta(self.liquidity, liquidityDelta)
	}
	
	tokensOwed0 := (feeGrowthInside0 - self.feeGrowthInside0Last) * self.liquidity
	tokensOwed1 := (feeGrowthInside1 - self.feeGrowthInside1Last) * self.liquidity

	if (liquidityDelta != 0) {
		self.liquidity = liquidityNext
	}

	self.feeGrowthInside0Last = feeGrowthInside0
	self.feeGrowthInside1Last = feeGrowthInside1
	if (tokensOwed0 > 0 || tokensOwed1 > 0) {
		self.tokensOwed0 += tokensOwed0
		self.tokensOwed1 += tokensOwed1
	}

	return self
}
