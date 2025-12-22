package staker

import (
	"chain/runtime"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	_ "gno.land/r/gnoswap/rbac"
)

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/staker",
		kvStore,
		func(_ store.KVStore) any {
			return NewStakerStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IStakerStore, _ PoolAccessor, _ EmissionAccessor, _ NFTAccessor) IStaker {
	return func(_ IStakerStore, _ PoolAccessor, _ EmissionAccessor, _ NFTAccessor) IStaker {
		return newMockStaker(version)
	}
}
