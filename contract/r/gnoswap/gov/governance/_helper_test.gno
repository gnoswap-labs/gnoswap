package governance

import (
	"chain/runtime/unsafe"
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
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

	// unsafe.CurrentRealm is used here because resetTestState is non-crossing
	// and has no `cur realm` in scope. The captured address is only used to
	// construct a fresh KV store keyed to the governance proxy realm.
	kvStore = store.NewKVStore(unsafe.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/gov/governance",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
			return NewGovernanceStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ int, rlm realm, _ IGovernanceStore, _ GovStakerAccessor) IGovernance {
	return func(_ int, rlm realm, _ IGovernanceStore, _ GovStakerAccessor) IGovernance {
		return newMockGovernance(version)
	}
}
