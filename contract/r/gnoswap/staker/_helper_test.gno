package staker

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	stakerAddr = access.MustGetAddress(prbac.ROLE_STAKER.String())
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
)

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/staker"))

	kvStore = store.NewKVStore(stakerAddr)
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/staker",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
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
