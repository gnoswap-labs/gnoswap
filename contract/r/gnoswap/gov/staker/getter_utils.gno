package staker

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

func cloneDelegationWithdraws(src []*DelegationWithdraw) []*DelegationWithdraw {
	if src == nil {
		return nil
	}
	cloned := make([]*DelegationWithdraw, len(src))
	for i, withdraw := range src {
		if withdraw != nil {
			cloned[i] = withdraw.Clone()
		}
	}
	return cloned
}
