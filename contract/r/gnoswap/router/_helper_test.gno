package router

import (
	"chain/runtime"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	_ "gno.land/r/gnoswap/rbac"
)

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/router",
		kvStore,
		func(_ store.KVStore) any {
			return NewRouterStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IRouterStore) IRouter {
	return func(_ IRouterStore) IRouter {
		return newMockRouter(version)
	}
}
