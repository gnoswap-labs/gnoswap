package router

import (
	"chain"
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/gnoswap/store/v1"
	"gno.land/p/gnoswap/version_manager/v1"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

	kvStore = store.NewKVStore(chain.PackageAddress("gno.land/r/gnoswap/router"))
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/router",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
			return NewRouterStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ int, rlm realm, _ IRouterStore) IRouter {
	return func(_ int, rlm realm, _ IRouterStore) IRouter {
		return newMockRouter(version)
	}
}
