package launchpad

func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}

	dst := make([]string, len(src))
	copy(dst, src)
	return dst
}

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
