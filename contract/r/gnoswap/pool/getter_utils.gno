package pool

import u256 "gno.land/p/gnoswap/uint256"

func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}

	cloned := make([]string, len(src))
	copy(cloned, src)
	return cloned
}

func cloneInt32Slice(src []int32) []int32 {
	if src == nil {
		return nil
	}

	cloned := make([]int32, len(src))
	copy(cloned, src)
	return cloned
}

func cloneFeeAmountTickSpacings(src map[uint32]int32) map[uint32]int32 {
	if src == nil {
		return nil
	}

	cloned := make(map[uint32]int32, len(src))
	for fee, spacing := range src {
		cloned[fee] = spacing
	}

	return cloned
}

func clonePositionInfo(src PositionInfo) PositionInfo {
	return PositionInfo{
		liquidity:                u256.Zero().Set(src.liquidity),
		feeGrowthInside0LastX128: u256.Zero().Set(src.feeGrowthInside0LastX128),
		feeGrowthInside1LastX128: u256.Zero().Set(src.feeGrowthInside1LastX128),
		tokensOwed0:              u256.Zero().Set(src.tokensOwed0),
		tokensOwed1:              u256.Zero().Set(src.tokensOwed1),
	}
}

func cloneObservationState(src ObservationState) ObservationState {
	cloned := make(map[uint16]Observation, len(src.observations))
	for k, v := range src.observations {
		cloned[k] = v.Clone()
	}

	return ObservationState{
		observations:    cloned,
		index:           src.index,
		cardinality:     src.cardinality,
		cardinalityNext: src.cardinalityNext,
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
