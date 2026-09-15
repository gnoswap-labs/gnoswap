package staker

// cloneInt64Slice returns an independent copy of src.
//
// Parameters:
//   - src: Integer slice to copy.
//
// Returns:
//   - []int64: copied slice, or nil when src is nil.
func cloneInt64Slice(src []int64) []int64 {
	if src == nil {
		return nil
	}
	cloned := make([]int64, len(src))
	copy(cloned, src)
	return cloned
}

// cloneStringInt64Map returns an independent copy of src.
//
// Parameters:
//   - src: String-to-int64 map to copy.
//
// Returns:
//   - map[string]int64: copied map, or nil when src is nil.
func cloneStringInt64Map(src map[string]int64) map[string]int64 {
	if src == nil {
		return nil
	}
	cloned := make(map[string]int64, len(src))
	for key, value := range src {
		cloned[key] = value
	}
	return cloned
}

// cloneDelegationWithdraws returns an independent copy of src.
//
// Parameters:
//   - src: Withdrawal slice to copy.
//
// Returns:
//   - []DelegationWithdraw: copied withdrawal slice, or nil when src is nil.
func cloneDelegationWithdraws(src []DelegationWithdraw) []DelegationWithdraw {
	if src == nil {
		return nil
	}
	cloned := make([]DelegationWithdraw, len(src))
	copy(cloned, src)
	return cloned
}
