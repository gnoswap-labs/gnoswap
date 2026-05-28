package protocol_fee

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
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee"))

	kvStore = store.NewKVStore(unsafe.CurrentRealm().Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/protocol_fee",
		kvStore,
		func(_ int, rlm realm, _ store.KVStore) any {
			return NewProtocolFeeStore(kvStore)
		},
	)

	implementation = nil
}

func makeMockInitializer(version string) func(_ int, rlm realm, _ IProtocolFeeStore) IProtocolFee {
	return func(_ int, rlm realm, _ IProtocolFeeStore) IProtocolFee {
		return newMockProtocolFee(version)
	}
}
