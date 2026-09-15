package common

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/gnoswap/store/v1"
	"gno.land/p/gnoswap/version_manager/v1"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

func resetTestState(cur realm, t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common"))

	kvStore = store.NewKVStore(cur.Address())
	versionManager = version_manager.NewVersionManager(
		"gno.land/r/gnoswap/common",
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

// registerGrc20regImpl installs the grc20reg-backed mock so helper tests
// resolve real tokens.
func registerGrc20regImpl(cur realm, t *testing.T) {
	resetTestState(cur, t)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/common/v1"))
	RegisterInitializer(cross(cur), func(_ int, rlm realm) ICommon {
		return &MockGrc20regCommon{}
	})
}
