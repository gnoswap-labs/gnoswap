package pool

import u256 "gno.land/p/gnoswap/uint256"

func clonePositionInfo(src PositionInfo) PositionInfo {
	return PositionInfo{
		liquidity:                u256.Zero().Set(src.liquidity),
		feeGrowthInside0LastX128: u256.Zero().Set(src.feeGrowthInside0LastX128),
		feeGrowthInside1LastX128: u256.Zero().Set(src.feeGrowthInside1LastX128),
		tokensOwed0:              u256.Zero().Set(src.tokensOwed0),
		tokensOwed1:              u256.Zero().Set(src.tokensOwed1),
	}
}

func NewDefaultPositionInfo() PositionInfo {
	return PositionInfo{
		liquidity:                u256.Zero(),
		feeGrowthInside0LastX128: u256.Zero(),
		feeGrowthInside1LastX128: u256.Zero(),
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
	}
}
