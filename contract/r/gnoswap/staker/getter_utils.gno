package staker

import "gno.land/p/nt/avl"

func cloneWarmups(warmups []Warmup) []Warmup {
	if warmups == nil {
		return nil
	}

	copied := make([]Warmup, len(warmups))
	copy(copied, warmups)
	return copied
}

func cloneAvlTree(tree *avl.Tree) *avl.Tree {
	if tree == nil {
		return nil
	}

	cloned := avl.NewTree()
	tree.Iterate("", "", func(key string, value any) bool {
		cloned.Set(key, value)
		return false
	})
	return cloned
}
