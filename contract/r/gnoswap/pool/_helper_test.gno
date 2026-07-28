package pool

import (
	"chain"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool"))

	kvStore = store.NewKVStore(chain.PackageAddress("gno.land/r/gnoswap/pool"))
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/pool",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
			return NewPoolStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ int, rlm realm, _ IPoolStore) IPool {
	return func(_ int, rlm realm, _ IPoolStore) IPool {
		return newMockPool(version)
	}
}
