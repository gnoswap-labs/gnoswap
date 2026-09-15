package staker

// cloneStringSlice returns an independent copy of src while preserving a nil input as nil.
//
// Parameters:
//   - src: String slice to copy.
//
// Returns:
//   - copied: New slice containing the same strings, or nil when src is nil.
func cloneStringSlice(src []string) []string {
	if src == nil {
		return nil
	}
	copied := make([]string, len(src))
	copy(copied, src)
	return copied
}

// cloneStringInt64Map returns an independent copy of a string-to-int64 map.
//
// Parameters:
//   - src: Map to copy, typically keyed by incentive ID.
//
// Returns:
//   - copied: New map with the same key/value pairs, or nil when src is nil.
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

// cloneStringBoolMap returns an independent copy of a string-to-bool map.
//
// Parameters:
//   - src: Map to copy, typically an incentive-ID membership index.
//
// Returns:
//   - copied: New map with the same key/value pairs, or nil when src is nil.
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

// cloneExternalIncentives returns independent copies of the external incentive values in src.
//
// Parameters:
//   - src: Slice of external incentives to copy.
//
// Returns:
//   - copied: New slice whose incentive values are cloned, or nil when src is nil.
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

// cloneWarmups returns an independent slice containing the warmup values in warmups.
//
// Parameters:
//   - warmups: Warmup tiers to copy.
//
// Returns:
//   - copied: New slice with the same warmup values, or nil when warmups is nil.
func cloneWarmups(warmups []Warmup) []Warmup {
	if warmups == nil {
		return nil
	}

	copied := make([]Warmup, len(warmups))
	copy(copied, warmups)
	return copied
}
