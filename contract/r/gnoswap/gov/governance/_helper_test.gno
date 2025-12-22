package governance

import (
	"chain/runtime"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	_ "gno.land/r/gnoswap/rbac"
)

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/gov/governance",
		kvStore,
		func(_ store.KVStore) any {
			return NewGovernanceStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IGovernanceStore, _ GovStakerAccessor) IGovernance {
	return func(_ IGovernanceStore, _ GovStakerAccessor) IGovernance {
		return newMockGovernance(version)
	}
}
