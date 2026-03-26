package pool


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
		liquidity:                src.liquidity,
		feeGrowthInside0LastX128: src.feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: src.feeGrowthInside1LastX128,
		tokensOwed0:              src.tokensOwed0,
		tokensOwed1:              src.tokensOwed1,
	}
}

func cloneObservationState(src *ObservationState) *ObservationState {
	if src == nil {
		return nil
	}

	return &ObservationState{
		observations:    make(map[uint16]*Observation),
		index:           src.index,
		cardinality:     src.cardinality,
		cardinalityNext: src.cardinalityNext,
	}
}

func NewDefaultPositionInfo() PositionInfo {
	return PositionInfo{
		liquidity:                "0",
		feeGrowthInside0LastX128: "0",
		feeGrowthInside1LastX128: "0",
		tokensOwed0:              "0",
		tokensOwed1:              "0",
	}
}
