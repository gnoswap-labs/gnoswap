package pool

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/mock"
	_ "gno.land/r/gnoswap/rbac"
)

var (
	_ IPool      = (*mock.MockPool)(nil)
	_ IPoolStore = (*mock.MockPoolStore)(nil)
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/pool",
		kvStore,
		func(_ store.KVStore) any {
			return NewPoolStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IPoolStore) IPool {
	return func(_ IPoolStore) IPool {
		return mock.NewMockPool(version)
	}
}
