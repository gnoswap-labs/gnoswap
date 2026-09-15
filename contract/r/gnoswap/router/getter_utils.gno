package router

// cloneStringInt64Map returns a copy so callers cannot reach the stored map.
//
// Parameters:
//   - src: map of token paths to pending protocol-fee amounts to copy; nil is preserved as nil.
//
// Returns:
//   - cloned: independently allocated map containing the same token-to-amount entries, or nil when src is nil
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
