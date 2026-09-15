package protocol_fee

// cloneStringInt64Map returns an independent map containing every key/value pair
// from src; a nil source produces a nil result.
//
// Parameters:
//   - src: source map of token paths to int64 amounts; nil is preserved as nil
//
// Returns:
//   - clone: shallow copy of src that can be modified without changing the source
func cloneStringInt64Map(src map[string]int64) map[string]int64 {
	if src == nil {
		return nil
	}

	dst := make(map[string]int64, len(src))
	for key, value := range src {
		dst[key] = value
	}

	return dst
}

// cloneStringSlice returns an independent copy of src; a nil source produces a nil
// result.
//
// Parameters:
//   - src: source slice of token paths; nil is preserved as nil
//
// Returns:
//   - clone: copied token-path slice with the same order and values as src
func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}

	dst := make([]string, len(src))
	copy(dst, src)
	return dst
}

// cloneInt64Slice returns an independent copy of src; a nil source produces a nil
// result.
//
// Parameters:
//   - src: source slice of epoch numbers or amounts; nil is preserved as nil
//
// Returns:
//   - clone: copied int64 slice with the same order and values as src
func cloneInt64Slice(src []int64) []int64 {
	if src == nil {
		return nil
	}

	dst := make([]int64, len(src))
	copy(dst, src)
	return dst
}
