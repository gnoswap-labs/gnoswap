package governance

func cloneInt64Slice(src []int64) []int64 {
	if src == nil {
		return nil
	}
	cloned := make([]int64, len(src))
	copy(cloned, src)
	return cloned
}

func cloneAddressSlice(src []address) []address {
	if src == nil {
		return nil
	}
	cloned := make([]address, len(src))
	copy(cloned, src)
	return cloned
}
