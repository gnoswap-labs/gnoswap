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

func cloneObservationState(src *ObservationState) *ObservationState {
	if src == nil {
		return nil
	}

	cloned := &ObservationState{
		observations:    make(map[uint16]Observation, len(src.observations)),
		index:           src.index,
		cardinality:     src.cardinality,
		cardinalityNext: src.cardinalityNext,
	}
	for k, v := range src.observations {
		cloned.observations[k] = v
	}
	return cloned
}
