package router

import (
	"chain/runtime"
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
