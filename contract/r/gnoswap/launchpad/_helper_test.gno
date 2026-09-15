package launchpad

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/gnoswap/store/v1"
	"gno.land/p/gnoswap/version_manager/v1"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac/v1"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Helper functions for testing
func resetTestState(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/launchpad"))

	kvStore = store.NewKVStore(cur.Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/launchpad",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
			return NewLaunchpadStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ int, rlm realm, _ ILaunchpadStore) ILaunchpad {
	return func(_ int, rlm realm, _ ILaunchpadStore) ILaunchpad {
		return newMockLaunchpad(version)
	}
}
