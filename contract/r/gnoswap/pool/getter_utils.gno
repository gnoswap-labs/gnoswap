package pool

// cloneInt32Slice returns an independent copy of an int32 slice.
//
// Parameters:
//   - src: Source slice; nil remains nil, while elements are copied into new storage.
//
// Returns:
//   - cloned: A slice with the same elements as src and no shared backing array.
func cloneInt32Slice(src []int32) []int32 {
	if src == nil {
		return nil
	}

	cloned := make([]int32, len(src))
	copy(cloned, src)
	return cloned
}

// cloneInt64Slice returns an independent copy of an int64 slice.
//
// Parameters:
//   - src: Source slice; nil remains nil, while elements are copied into new storage.
//
// Returns:
//   - cloned: A slice with the same elements as src and no shared backing array.
func cloneInt64Slice(src []int64) []int64 {
	if src == nil {
		return nil
	}

	cloned := make([]int64, len(src))
	copy(cloned, src)
	return cloned
}

// cloneStringSlice returns an independent copy of a string slice.
//
// Parameters:
//   - src: Source slice; nil remains nil, while elements are copied into new storage.
//
// Returns:
//   - cloned: A slice with the same elements as src and no shared backing array.
func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}

	cloned := make([]string, len(src))
	copy(cloned, src)
	return cloned
}

// cloneUint32Slice returns an independent copy of a uint32 slice.
//
// Parameters:
//   - src: Source slice; nil remains nil, while elements are copied into new storage.
//
// Returns:
//   - cloned: A slice with the same elements as src and no shared backing array.
func cloneUint32Slice(src []uint32) []uint32 {
	if src == nil {
		return nil
	}

	cloned := make([]uint32, len(src))
	copy(cloned, src)
	return cloned
}

// cloneFeeAmountTickSpacings returns a detached copy of a fee-to-tick-spacing map.
//
// Parameters:
//   - src: Source map from fee tier to tick spacing; nil remains nil.
//
// Returns:
//   - cloned: A map containing the same fee-tier mappings without sharing src's map storage.
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

// cloneStringInt64Map returns a detached copy of a string-to-int64 map.
//
// Parameters:
//   - src: Source map; nil remains nil, while each key and value is copied.
//
// Returns:
//   - cloned: A map containing the same entries without sharing src's map storage.
func cloneStringInt64Map(src map[string]int64) map[string]int64 {
	if src == nil {
		return nil
	}

	cloned := make(map[string]int64, len(src))
	for k, v := range src {
		cloned[k] = v
	}

	return cloned
}

// NewDefaultPositionInfo returns the zero-accounting position state used for a new pool position.
//
// Returns:
//   - info: Position info with zero liquidity, zero fee-growth checkpoints, and no tokens owed.
func NewDefaultPositionInfo() PositionInfo {
	return PositionInfo{
		liquidity:                "0",
		feeGrowthInside0LastX128: "0",
		feeGrowthInside1LastX128: "0",
		tokensOwed0:              0,
		tokensOwed1:              0,
	}
}
