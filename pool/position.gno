package gnoswap

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

var (
	Position avl.Tree // bytes32 => Position.Info
)


// info stored for each user's position
type PositionInfo struct {
	// the amount of liquidity owned by this position
	liquidity bigdec // XX bigint??

	// fee grwoth per unit of liquidity as of the last update to liquidity or fees owed
	feeGrowthInside0Last bigdec // XX bigint??
	feeGrowthInside1Last bigdec // XX bigint??

	// the fees owed to the position owner in token0/token1
	tokensOwed0 bigdec // XX bigint??
	tokensOwed1 bigdec // XX bigint??
}


func PositionGet(
	// self *PositionInfo,
	owner std.Address,
	tickLower bigint, // int64
	tickUpper bigint, // int64
) (string) {
	// position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
	// key := ufmt.Sprintf("+%v %d %d", owner, tickLower, tickUpper)
	// sum := sha3.Sum256([]byte(key))[:]

	key := ufmt.Sprintf("%s_%d_%d", owner.String(), tickLower, tickUpper)
	return key
}

func PositionUpdate(
	key string,
	liquidityDelta bigdec,
	feeGrowthInside0 bigdec,
	feeGrowthInside1 bigdec,
) (PositionInfo) {
	var _self PositionInfo
	var ok bool

	_self, ok = positions.Get(key)
	if !ok {
		panic("position not found POSITION")
	}

	var liquidityNext bigdec

	if (liquidityDelta == 0) {
		require(_self.liquidity > 0, "NP")
		liquidityNext = _self.liquidity
	} else {
		liquidityNext = _self.liquidity + liquidityDelta
	}

	var tokensOwed0 bigdec = (feeGrowthInside0 - _self.feeGrowthInside0Last) * _self.liquidity
	var tokensOwed1 bigdec = (feeGrowthInside1 - _self.feeGrowthInside1Last) * _self.liquidity

	if (liquidityDelta != 0) {
		_self.liquidity = liquidityNext
	}

	_self.feeGrowthInside0Last = feeGrowthInside0
	_self.feeGrowthInside1Last = feeGrowthInside1
	if (tokensOwed0 > 0 || tokensOwed1 > 0) {
		_self.tokensOwed0 += tokensOwed0
		_self.tokensOwed1 += tokensOwed1
	}

	return _self
}

