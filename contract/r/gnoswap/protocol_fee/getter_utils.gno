package protocol_fee

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

func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}

	dst := make([]string, len(src))
	copy(dst, src)
	return dst
}
