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
	// Initialize config if not already initialized
	if currentConfig == nil || currentConfig.roles[ROLE_ADMIN] == "" {
		cfg, err := initializeDefaultRoles()
		uassert.NoError(t, err)
		currentConfig = cfg
	}

	t.Run("update success", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		adminRealm := std.NewUserRealm(adminAddr)
		testing.SetRealm(adminRealm)

		err = CreateRole(cross, "another_test_admin", testAdminAddr)
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

	t.Run("update fails while update non-existent role", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = UpdateRoleAddress(cross, "non_existent_role", testRealm1Addr)
		uassert.Error(t, err)
	})

	t.Run("update success with governance", func(t *testing.T) {
		// First create a role as admin
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = CreateRole(cross, "test_gov_update", testAdminAddr)
		uassert.NoError(t, err)

		// Then update it as governance
		govAddr, err := GetAddress(ROLE_GOVERNANCE)
		uassert.NoError(t, err)
		testing.SetOriginCaller(govAddr)

		err = UpdateRoleAddress(cross, "test_gov_update", testRealm2Addr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		updatedAddr := actual.roles["test_gov_update"]
		uassert.Equal(t, testRealm2Addr, updatedAddr)
	})

	t.Run("governance cannot update critical roles", func(t *testing.T) {
		govAddr, err := GetAddress(ROLE_GOVERNANCE)
		uassert.NoError(t, err)
		testing.SetOriginCaller(govAddr)

		// Try to update admin role
		err = UpdateRoleAddress(cross, ROLE_ADMIN, testRealm1Addr)
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, "only admin can update critical roles")

		// Try to update devops role
		err = UpdateRoleAddress(cross, ROLE_DEVOPS, testRealm1Addr)
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, "only admin can update critical roles")
	})
}

func TestCreateRole(t *testing.T) {
	// Initialize config if not already initialized
	if currentConfig == nil || currentConfig.roles[ROLE_ADMIN] == "" {
		cfg, err := initializeDefaultRoles()
		uassert.NoError(t, err)
		currentConfig = cfg
	}

	testNewRoleAddr := testutils.TestAddress("test_new_role")
	testAnotherAddr := testutils.TestAddress("test_another_role")

	t.Run("create new role success", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = CreateRole(cross, "custom_role", testNewRoleAddr)
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
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = CreateRole(cross, "duplicate_role", testNewRoleAddr)
		uassert.NoError(t, err)

		err = CreateRole(cross, "duplicate_role", testAnotherAddr)
		uassert.Error(t, err)
	})
}

func TestSetRole(t *testing.T) {
	// Initialize config if not already initialized
	if currentConfig == nil || currentConfig.roles[ROLE_ADMIN] == "" {
		cfg, err := initializeDefaultRoles()
		uassert.NoError(t, err)
		currentConfig = cfg
	}

	testNewRoleAddr := testutils.TestAddress("test_new_role")
	testAuditorAddr := testutils.TestAddress("test_auditor")
	testReviewerAddr := testutils.TestAddress("test_reviewer")

	t.Run("success with new role", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = SetRole(cross, "test_auditor", testAuditorAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		uassert.Equal(t, testAuditorAddr, actual.roles["test_auditor"])
	})

	t.Run("set new role success", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = SetRole(cross, "custom_role_2", testNewRoleAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		roleAddr := actual.roles["custom_role_2"]
		uassert.Equal(t, testNewRoleAddr, roleAddr)
	})

	t.Run("success updating existing role", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = CreateRole(cross, "test_reviewer", testReviewerAddr)
		uassert.NoError(t, err)

		newReviewerAddr := testutils.TestAddress("test_reviewer_new")
		err = SetRole(cross, "test_reviewer", newReviewerAddr)
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		uassert.Equal(t, newReviewerAddr, actual.roles["test_reviewer"])
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

	t.Run("success with governance address", func(t *testing.T) {
		govAddr, err := GetAddress(ROLE_GOVERNANCE)
		uassert.NoError(t, err)
		testing.SetOriginCaller(govAddr)

		err = SetRole(cross, "test_gov_role", testutils.TestAddress("test_gov_role"))
		uassert.NoError(t, err)

		actual := getCurrentConfig()
		uassert.Equal(t, testutils.TestAddress("test_gov_role"), actual.roles["test_gov_role"])
	})

	t.Run("governance cannot set critical roles", func(t *testing.T) {
		govAddr, err := GetAddress(ROLE_GOVERNANCE)
		uassert.NoError(t, err)
		testing.SetOriginCaller(govAddr)

		// Try to set admin role
		err = SetRole(cross, ROLE_ADMIN, testutils.TestAddress("new_admin"))
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, "only admin can set critical roles")

		// Try to set devops role
		err = SetRole(cross, ROLE_DEVOPS, testutils.TestAddress("new_devops"))
		uassert.Error(t, err)
		uassert.ErrorContains(t, err, "only admin can set critical roles")
	})
}

func TestDeleteRole(t *testing.T) {
	// Initialize config if not already initialized
	if currentConfig == nil || currentConfig.roles[ROLE_ADMIN] == "" {
		cfg, err := initializeDefaultRoles()
		uassert.NoError(t, err)
		currentConfig = cfg
	}

	testRoleAddr := testutils.TestAddress("test_role_to_delete")

	t.Run("success delete existing role", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = CreateRole(cross, "test_role_to_delete", testRoleAddr)
		uassert.NoError(t, err)

		exists := RoleExists("test_role_to_delete")
		uassert.Equal(t, true, exists)

		err = DeleteRole(cross, "test_role_to_delete")
		uassert.NoError(t, err)

		exists = RoleExists("test_role_to_delete")
		uassert.Equal(t, false, exists)
	})

	t.Run("fail to delete non-existent role", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = DeleteRole(cross, "non_existent_role")
		uassert.Error(t, err)
	})

	t.Run("fail to delete admin role", func(t *testing.T) {
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = DeleteRole(cross, ROLE_ADMIN)
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
		adminAddr, err := GetAddress(ROLE_ADMIN)
		uassert.NoError(t, err)
		testing.SetOriginCaller(adminAddr)

		err = DeleteRole(cross, "")
		uassert.Error(t, err)
	})
}
