package access

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/rbac"
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
	t.Run("update success", func(t *testing.T) {
		// consts.ADMIN 직접 사용
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := CreateRole(cross, "another_test_admin", testAdminAddr)
		uassert.NoError(t, err)

		err = UpdateRoleAddress(cross, "another_test_admin", testRealm1Addr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		updatedAddr := actual.roles["another_test_admin"]
		uassert.Equal(t, testRealm1Addr, updatedAddr)

		err = rbac.CheckPermission("another_test_admin", PERM_ACCESS, updatedAddr)
		uassert.NoError(t, err)
	})

	t.Run("update fails while uninitialized", func(t *testing.T) {
		backup := currentConfig
		currentConfig = nil

		err := UpdateRoleAddress(cross, "another_test_admin", testRealm1Addr)
		uassert.Error(t, err)

		currentConfig = backup
	})

	t.Run("update fails while update non-existent role", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := UpdateRoleAddress(cross, "non_existent_role", testRealm1Addr)
		uassert.Error(t, err)
	})
}

func TestCreateRole(t *testing.T) {
	testNewRoleAddr := testutils.TestAddress("test_new_role")
	testAnotherAddr := testutils.TestAddress("test_another_role")

	t.Run("create new role success", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := CreateRole(cross, "custom_role", testNewRoleAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		roleAddr := actual.roles["custom_role"]
		uassert.Equal(t, testNewRoleAddr, roleAddr)

		err = rbac.CheckPermission("custom_role", PERM_ACCESS, testNewRoleAddr)
		uassert.NoError(t, err)

		err = rbac.CheckPermission("custom_role", PERM_ACCESS, testAnotherAddr)
		uassert.Error(t, err)
	})

	t.Run("create role fails while uninitialized", func(t *testing.T) {
		backup := currentConfig
		currentConfig = nil
		err := CreateRole(cross, "failed_role", testNewRoleAddr)
		uassert.Error(t, err)
		currentConfig = backup
	})

	t.Run("create duplicate role fails", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := CreateRole(cross, "duplicate_role", testNewRoleAddr)
		uassert.NoError(t, err)

		err = CreateRole(cross, "duplicate_role", testAnotherAddr)
		uassert.Error(t, err)
	})
}

func TestSetRole(t *testing.T) {
	testNewRoleAddr := testutils.TestAddress("test_new_role")
	testAnotherAddr := testutils.TestAddress("test_another_role")
	testAuditorAddr := testutils.TestAddress("test_auditor")
	testReviewerAddr := testutils.TestAddress("test_reviewer")

	t.Run("success with new role", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := SetRole(cross, "test_auditor", testAuditorAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		uassert.Equal(t, testAuditorAddr, actual.roles["test_auditor"])

		err = rbac.CheckPermission("test_auditor", PERM_ACCESS, testAuditorAddr)
		uassert.NoError(t, err)
	})

	t.Run("set new role success", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := SetRole(cross, "custom_role_2", testNewRoleAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		roleAddr := actual.roles["custom_role_2"]
		uassert.Equal(t, testNewRoleAddr, roleAddr)

		err = rbac.CheckPermission("custom_role_2", PERM_ACCESS, testNewRoleAddr)
		uassert.NoError(t, err)

		err = rbac.CheckPermission("custom_role_2", PERM_ACCESS, testAnotherAddr)
		uassert.Error(t, err)
	})

	t.Run("success updating existing role", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := CreateRole(cross, "test_reviewer", testReviewerAddr)
		uassert.NoError(t, err)

		newReviewerAddr := testutils.TestAddress("test_reviewer_new")
		err = SetRole(cross, "test_reviewer", newReviewerAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		uassert.Equal(t, newReviewerAddr, actual.roles["test_reviewer"])

		err = rbac.CheckPermission("test_reviewer", PERM_ACCESS, testReviewerAddr)
		uassert.Error(t, err)

		err = rbac.CheckPermission("test_reviewer", PERM_ACCESS, newReviewerAddr)
		uassert.NoError(t, err)
	})

	t.Run("set role fails while uninitialized", func(t *testing.T) {
		backup := currentConfig
		currentConfig = nil
		err := SetRole(cross, "failed_role", testNewRoleAddr)
		uassert.Error(t, err)
		currentConfig = backup
	})

	t.Run("fail with non-admin address", func(t *testing.T) {
		testing.SetRealm(std.NewUserRealm(testutils.TestAddress("non_admin")))
		err := SetRole(cross, "test_auditor", testAuditorAddr)
		uassert.Error(t, err)
	})
}

func TestDeleteRole(t *testing.T) {
	testRoleAddr := testutils.TestAddress("test_role_to_delete")

	t.Run("success delete existing role", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := CreateRole(cross, "test_role_to_delete", testRoleAddr)
		uassert.NoError(t, err)

		exists := RoleExists("test_role_to_delete")
		uassert.Equal(t, true, exists)

		err = DeleteRole(cross, "test_role_to_delete")
		uassert.NoError(t, err)

		exists = RoleExists("test_role_to_delete")
		uassert.Equal(t, false, exists)

		err = rbac.CheckPermission("test_role_to_delete", PERM_ACCESS, testRoleAddr)
		uassert.Error(t, err)
	})

	t.Run("fail to delete non-existent role", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := DeleteRole(cross, "non_existent_role")
		uassert.Error(t, err)
	})

	t.Run("fail to delete admin role", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := DeleteRole(cross, ROLE_ADMIN)
		uassert.Error(t, err)
	})

	t.Run("fail while uninitialized", func(t *testing.T) {
		backup := currentConfig
		currentConfig = nil
		err := DeleteRole(cross, "any_role")
		uassert.Error(t, err)
		currentConfig = backup
	})

	t.Run("fail with empty role name", func(t *testing.T) {
		adminRealm := std.NewUserRealm(consts.ADMIN)
		testing.SetRealm(adminRealm)

		err := DeleteRole(cross, "")
		uassert.Error(t, err)
	})
}
