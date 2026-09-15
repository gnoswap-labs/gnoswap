package launchpad

// cloneInt64Map returns an independent copy of src, preserving nil as nil.
//
// Parameters:
//   - src: map from int64 keys to int64 values to copy.
//
// Returns:
//   - clone: new map containing the same entries, or nil when src is nil.
func cloneInt64Map(src map[int64]int64) map[int64]int64 {
	if src == nil {
		return nil
	}

	dst := make(map[int64]int64, len(src))
	for key, value := range src {
		dst[key] = value
	}
	return dst
}
