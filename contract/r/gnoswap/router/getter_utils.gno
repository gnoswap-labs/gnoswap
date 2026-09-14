package router

// cloneStringInt64Map returns a copy so callers cannot reach the stored map.
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
