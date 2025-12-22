package protocol_fee

import (
	"chain/runtime"
	"testing"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	_ "gno.land/r/gnoswap/rbac"
)

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/protocol_fee",
		kvStore,
		func(_ store.KVStore) any {
			return NewProtocolFeeStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ IProtocolFeeStore) IProtocolFee {
	return func(_ IProtocolFeeStore) IProtocolFee {
		return newMockProtocolFee(version)
	}
}
