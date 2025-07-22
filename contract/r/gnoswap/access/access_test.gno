package access

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

var (
	testAdminAddr  = testutils.TestAddress("test_admin")
	testRouterAddr = testutils.TestAddress("test_router")

	testRealm1Addr = testutils.TestAddress("test_realm1")
	testRealm2Addr = testutils.TestAddress("test_realm2")
)

func getAdminRealm() std.Realm {
	adminAddr, _ := GetAddress(ROLE_ADMIN)
	return std.NewUserRealm(adminAddr)
}

func TestInitialize(t *testing.T) {
	t.Run("success with valid config", func(t *testing.T) {
		cfg := newConfig()
		cfg.roles["test_admin"] = testAdminAddr
		cfg.roles["test_router"] = testRouterAddr

		err := initialize(cfg)
		uassert.NoError(t, err)

		actual := getCurrentConfig()

		adminAddr := actual.roles["test_admin"]
		routerAddr := actual.roles["test_router"]

		uassert.Equal(t, testAdminAddr, adminAddr)
		uassert.Equal(t, testRouterAddr, routerAddr)
	})

	t.Run("initialize with nil config", func(t *testing.T) {
		err := initialize(nil)
		uassert.Error(t, err)
	})
}
