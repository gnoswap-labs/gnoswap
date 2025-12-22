package staker

import (
	"chain/runtime"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/gov/staker",
		kvStore,
		func(_ store.KVStore) any {
			return NewGovStakerStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IGovStakerStore) IGovStaker {
	return func(_ IGovStakerStore) IGovStaker {
		return newMockGovStaker(version)
	}
}

// AVL tree test utilities

// mapToAvlTreeUserDelegations converts nested delegation map to AVL tree
func mapToAvlTreeUserDelegations(m map[string]map[string][]int64) *avl.Tree {
	tree := avl.NewTree()
	for delegator, delegatees := range m {
		innerTree := avl.NewTree()
		for delegatee, ids := range delegatees {
			innerTree.Set(delegatee, ids)
		}
		tree.Set(delegator, innerTree)
	}
	return tree
}

// mapToAvlTreeUint256 converts map[string]*u256.Uint to AVL tree
func mapToAvlTreeUint256(m map[string]*u256.Uint) *avl.Tree {
	tree := avl.NewTree()
	for k, v := range m {
		tree.Set(k, v)
	}
	return tree
}

// mapToAvlTreeInt64 converts map[string]int64 to AVL tree
func mapToAvlTreeInt64(m map[string]int64) *avl.Tree {
	tree := avl.NewTree()
	for k, v := range m {
		tree.Set(k, v)
	}
	return tree
}
