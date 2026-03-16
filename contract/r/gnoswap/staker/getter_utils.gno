package staker

import avl "gno.land/p/nt/avl/v0"

func cloneWarmups(warmups []Warmup) []Warmup {
	if warmups == nil {
		return nil
	}

	copied := make([]Warmup, len(warmups))
	copy(copied, warmups)
	return copied
}

func cloneExternalIncentives(tree *avl.Tree) avl.Tree {
	var cloned avl.Tree
	tree.Iterate("", "", func(key string, value any) bool {
		state := value.(ExternalIncentiveState)
		cloned.Set(key, ExternalIncentiveState{
			CollectedReward: state.CollectedReward,
			LastCollectTime: state.LastCollectTime,
		})
		return false
	})
	return cloned
}
