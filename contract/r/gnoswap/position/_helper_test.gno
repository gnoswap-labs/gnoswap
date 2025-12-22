package position

import (
	"chain/runtime"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	_ "gno.land/r/gnoswap/rbac"
)

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/position",
		kvStore,
		func(_ store.KVStore) any {
			return NewPositionStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IPositionStore) IPosition {
	return func(_ IPositionStore) IPosition {
		return newMockPosition(version)
	}
}
