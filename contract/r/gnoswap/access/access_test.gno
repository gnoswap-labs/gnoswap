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

func TestUpdateRoleAddress(t *testing.T) {
	initializeDefaultRoles()

	adminAddr := std.Address(ADMIN)
	t.Run("update success", func(t *testing.T) {
		testing.SetOriginCaller(adminAddr)

		err := CreateRole(cross, "another_test_admin", testAdminAddr)
		uassert.NoError(t, err)

		err = UpdateRoleAddress(cross, "another_test_admin", testRealm1Addr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		updatedAddr := actual.roles["another_test_admin"]
		uassert.Equal(t, testRealm1Addr, updatedAddr)
	})

	t.Run("update fails while uninitialized", func(t *testing.T) {
		backup := currentConfig
		currentConfig = nil

		err := UpdateRoleAddress(cross, "another_test_admin", testRealm1Addr)
		uassert.Error(t, err)

		currentConfig = backup
	})
}

func TestCreateRole(t *testing.T) {
	initializeDefaultRoles()
	testNewRoleAddr := testutils.TestAddress("test_new_role")
	testAnotherAddr := testutils.TestAddress("test_another_role")

	t.Run("create new role success", func(t *testing.T) {
		adminAddr := std.Address(ADMIN)
		testing.SetOriginCaller(adminAddr)
		err := CreateRole(cross, "custom_role", testNewRoleAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		roleAddr := actual.roles["custom_role"]
		uassert.Equal(t, testNewRoleAddr, roleAddr)
	})

	t.Run("create role fails while uninitialized", func(t *testing.T) {
		backup := currentConfig
		currentConfig = nil
		err := CreateRole(cross, "failed_role", testNewRoleAddr)
		uassert.Error(t, err)
		currentConfig = backup
	})

	t.Run("create duplicate role fails", func(t *testing.T) {
		adminAddr := std.Address(ADMIN)
		testing.SetOriginCaller(adminAddr)

		err := CreateRole(cross, "duplicate_role", testNewRoleAddr)
		uassert.NoError(t, err)

		err = CreateRole(cross, "duplicate_role", testAnotherAddr)
		uassert.Error(t, err)
	})
}
