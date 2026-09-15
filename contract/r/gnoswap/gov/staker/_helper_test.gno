package staker

import (
	"chain/runtime/unsafe"
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/gnoswap/store/v1"
	"gno.land/p/gnoswap/version_manager/v1"
	"gno.land/r/gnoswap/access/v1"
	_ "gno.land/r/gnoswap/rbac/v1"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker"))

	kvStore = store.NewKVStore(unsafe.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/gov/staker",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
			return NewGovStakerStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ int, rlm realm, _ IGovStakerStore) IGovStaker {
	return func(_ int, rlm realm, _ IGovStakerStore) IGovStaker {
		return newMockGovStaker(version)
	}
}
