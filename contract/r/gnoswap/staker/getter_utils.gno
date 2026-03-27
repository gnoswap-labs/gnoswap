package staker

func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}
	copied := make([]string, len(src))
	copy(copied, src)
	return copied
}

func cloneUint64Slice(src []uint64) []uint64 {
	if src == nil {
		return nil
	}
	copied := make([]uint64, len(src))
	copy(copied, src)
	return copied
}

func cloneInt64Slice(src []int64) []int64 {
	if src == nil {
		return nil
	}
	copied := make([]int64, len(src))
	copy(copied, src)
	return copied
}

func cloneInt32Slice(src []int32) []int32 {
	if src == nil {
		return nil
	}
	copied := make([]int32, len(src))
	copy(copied, src)
	return copied
}

func cloneStringInt64Map(src map[string]int64) map[string]int64 {
	if src == nil {
		return nil
	}

	copied := make(map[string]int64, len(src))
	for key, value := range src {
		copied[key] = value
	}
	return copied
}

func cloneStringBoolMap(src map[string]bool) map[string]bool {
	if src == nil {
		return nil
	}

	copied := make(map[string]bool, len(src))
	for key, value := range src {
		copied[key] = value
	}

	return copied
}

func cloneExternalIncentives(src []ExternalIncentive) []ExternalIncentive {
	if src == nil {
		return nil
	}

	copied := make([]ExternalIncentive, len(src))
	for i := range src {
		copied[i] = *src[i].Clone()
	}

	return copied
}

func cloneWarmups(warmups []Warmup) []Warmup {
	if warmups == nil {
		return nil
	}

	copied := make([]Warmup, len(warmups))
	copy(copied, warmups)
	return copied
}
