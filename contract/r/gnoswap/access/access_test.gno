package access

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/rbac"
)

var (
	testAdminAddr  = testutils.TestAddress("test_admin")
	testRouterAddr = testutils.TestAddress("test_router")

	testRealm1Addr = testutils.TestAddress("test_realm1")
	testRealm2Addr = testutils.TestAddress("test_realm2")
)

func TestInitialize(t *testing.T) {
	t.Run("success with valid config", func(t *testing.T) {
		cfg := DefaultConfig()
		cfg.Roles["test_admin"] = testAdminAddr
		cfg.Roles["test_router"] = testRouterAddr

		err := Initialize(cfg)
		uassert.NoError(t, err)

		actual := GetCurrentConfig()

		// retrieve the config informations
		adminAddr := actual.Roles["test_admin"]
		routerAddr := actual.Roles["test_router"]

		uassert.Equal(t, testAdminAddr, adminAddr)
		uassert.Equal(t, testRouterAddr, routerAddr)
	})

	t.Run("initialize with nil config", func(t *testing.T) {
		err := Initialize(nil)
		uassert.Error(t, err)
	})
}

func TestUpdateRoleAddress(t *testing.T) {
	t.Run("update success", func(t *testing.T) {
		cfg := DefaultConfig()
		cfg.Roles[ROLE_ADMIN] = testAdminAddr
		err := Initialize(cfg)
		uassert.NoError(t, err)

		err = UpdateRoleAddress(ROLE_ADMIN, testRealm1Addr)
		uassert.NoError(t, err)

		actual := GetCurrentConfig()
		adminAddr := actual.Roles[ROLE_ADMIN]
		uassert.Equal(t, testRealm1Addr, adminAddr, ufmt.Sprintf("expected %s, got %s", testRealm1Addr, adminAddr))

		err = rbac.CheckPermission(ROLE_ADMIN, PERM_ACCESS, adminAddr)
		uassert.NoError(t, err)
	})

	t.Run("update fails while uninitialized", func(t *testing.T) {
		currentConfig = nil
		err := UpdateRoleAddress(ROLE_ADMIN, testRealm1Addr)
		uassert.Error(t, err)
	})

	t.Run("update fails while update non-existent role", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		err = UpdateRoleAddress("non_existent_role", testRealm1Addr)
		uassert.Error(t, err)
	})
}

func TestUserRealm(t *testing.T) {
	testAdminAddr2 := testutils.TestAddress("test_admin2")
	testGovAddr := testutils.TestAddress("test_governance")
	otherAddr := testutils.TestAddress("other")
	testOperatorAddr := testutils.TestAddress("test_operator")
	testValidatorAddr := testutils.TestAddress("test_validator")
	testUserAddr := testutils.TestAddress("test_user")

	cfg := DefaultConfig()
	cfg.Roles["test_admin2"] = testAdminAddr2
	cfg.Roles["test_governance"] = testGovAddr
	cfg.Roles["test_operator"] = testOperatorAddr
	cfg.Roles["test_validator"] = testValidatorAddr

	err := Initialize(cfg)
	uassert.NoError(t, err)

	t.Run("Role Permission Tests", func(t *testing.T) {
		tests := []struct {
			name      string
			role      string
			addr      std.Address
			shouldErr bool
		}{
			{
				name:      "test_admin2 address accessing test_admin2 role",
				role:      "test_admin2",
				addr:      testAdminAddr2,
				shouldErr: false,
			},
			{
				name:      "non-test_admin2 address accessing test_admin2 role",
				role:      "test_admin2",
				addr:      otherAddr,
				shouldErr: true,
			},
			{
				name:      "test_governance address accessing test_governance role",
				role:      "test_governance",
				addr:      testGovAddr,
				shouldErr: false,
			},
			{
				name:      "non-test_governance address accessing test_governance role",
				role:      "test_governance",
				addr:      otherAddr,
				shouldErr: true,
			},
			{
				name:      "empty address accessing admin role",
				role:      "test_admin2",
				addr:      std.Address(""),
				shouldErr: true,
			},
			{
				name:      "operator address accessing validator role",
				role:      "test_validator",
				addr:      testOperatorAddr,
				shouldErr: true,
			},
			{
				name:      "regular user address accessing operator role",
				role:      "test_operator",
				addr:      testUserAddr,
				shouldErr: true,
			},
			{
				name:      "accessing non-existent role",
				role:      "non_existent_role",
				addr:      testUserAddr,
				shouldErr: true,
			},
			{
				name:      "validator address accessing own role",
				role:      "test_validator",
				addr:      testValidatorAddr,
				shouldErr: false,
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				err := rbac.CheckPermission(tt.role, PERM_ACCESS, tt.addr)
				if tt.shouldErr {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
				}
			})
		}
	})
}

func TestMultiRoleValidation(t *testing.T) {
	testLiquidityAddr := testutils.TestAddress("test_liquidity")
	testStakerAddr := testutils.TestAddress("test_staker")
	testMultiRoleAddr := testutils.TestAddress("test_multi_role")

	cfg := DefaultConfig()
	cfg.Roles["test_liquidity"] = testLiquidityAddr
	cfg.Roles["test_staker"] = testStakerAddr

	// add multiple roles to one address
	cfg.Roles["test_liquidity_multi"] = testMultiRoleAddr
	cfg.Roles["test_staker_multi"] = testMultiRoleAddr

	err := Initialize(cfg)
	uassert.NoError(t, err)

	t.Run("Multiple Role Assignment Validation", func(t *testing.T) {
		tests := []struct {
			name      string
			addr      std.Address
			roles     []string
			perms     []string
			shouldErr bool
		}{
			{
				name:      "address with correct multiple roles",
				addr:      testMultiRoleAddr,
				roles:     []string{"test_liquidity_multi", "test_staker_multi"},
				perms:     []string{PERM_ACCESS, PERM_ACCESS},
				shouldErr: false,
			},
			{
				name:      "address with single role trying multiple access",
				addr:      testLiquidityAddr,
				roles:     []string{"test_liquidity", "test_staker"},
				perms:     []string{PERM_ACCESS, PERM_ACCESS},
				shouldErr: true,
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				var lastErr error
				for i, role := range tt.roles {
					err := rbac.CheckPermission(role, tt.perms[i], tt.addr)
					if err != nil {
						lastErr = err
						break
					}
				}

				if tt.shouldErr {
					uassert.Error(t, lastErr)
				} else {
					uassert.NoError(t, lastErr)
				}
			})
		}
	})
}

func TestCreateRole(t *testing.T) {
	testNewRoleAddr := testutils.TestAddress("test_new_role")
	testAnotherAddr := testutils.TestAddress("test_another_role")

	t.Run("create new role success", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		err = CreateRole("custom_role", testNewRoleAddr)
		uassert.NoError(t, err)

		// verify role was created correctly
		actual := GetCurrentConfig()
		roleAddr := actual.Roles["custom_role"]
		uassert.Equal(t, testNewRoleAddr, roleAddr)

		// verify permission is set correctly
		err = rbac.CheckPermission("custom_role", PERM_ACCESS, testNewRoleAddr)
		uassert.NoError(t, err)

		// verify different address cannot access the role
		err = rbac.CheckPermission("custom_role", PERM_ACCESS, testAnotherAddr)
		uassert.Error(t, err)
	})

	t.Run("create role fails while uninitialized", func(t *testing.T) {
		currentConfig = nil
		err := CreateRole("failed_role", testNewRoleAddr)
		uassert.Error(t, err)
	})

	t.Run("create duplicate role fails", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		// create first role
		err = CreateRole("duplicate_role", testNewRoleAddr)
		uassert.NoError(t, err)

		// attempt to create same role again
		err = CreateRole("duplicate_role", testAnotherAddr)
		uassert.Error(t, err)
	})
}

func TestRoleExists(t *testing.T) {
	testRoleAddr := testutils.TestAddress("test_role_exists")

	t.Run("check existing role", func(t *testing.T) {
		cfg := DefaultConfig()
		cfg.Roles["existing_role"] = testRoleAddr
		err := Initialize(cfg)
		uassert.NoError(t, err)

		exists := RoleExists("existing_role")
		uassert.Equal(t, true, exists)
	})

	t.Run("check non-existing role", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		exists := RoleExists("non_existing_role")
		uassert.Equal(t, false, exists)
	})

	t.Run("check while uninitialized", func(t *testing.T) {
		currentConfig = nil
		exists := RoleExists("any_role")
		uassert.Equal(t, false, exists)
	})
}

func TestGetRoles(t *testing.T) {
	testRole1Addr := testutils.TestAddress("test_role1_get")
	testRole2Addr := testutils.TestAddress("test_role2_get")

	t.Run("get roles from initialized config", func(t *testing.T) {
		cfg := DefaultConfig()
		cfg.Roles["role1"] = testRole1Addr
		cfg.Roles["role2"] = testRole2Addr
		err := Initialize(cfg)
		uassert.NoError(t, err)

		roles := GetRoles()
		uassert.Equal(t, 2, len(roles))

		// check if both roles exist in the result
		foundRole1 := false
		foundRole2 := false
		for _, role := range roles {
			if role == "role1" {
				foundRole1 = true
			}
			if role == "role2" {
				foundRole2 = true
			}
		}
		uassert.Equal(t, true, foundRole1)
		uassert.Equal(t, true, foundRole2)
	})

	t.Run("get roles from empty config", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		roles := GetRoles()
		uassert.Equal(t, 0, len(roles))
	})

	t.Run("get roles while uninitialized", func(t *testing.T) {
		currentConfig = nil
		roles := GetRoles()
		uassert.Equal(t, 0, len(roles))
	})
}

func TestSetConfig(t *testing.T) {
	testManagerAddr := testutils.TestAddress("test_manager")
	testAnalystAddr := testutils.TestAddress("test_analyst")

	t.Run("success with valid config", func(t *testing.T) {
		cfg := DefaultConfig()
		cfg.Roles["test_manager"] = testManagerAddr
		cfg.Roles["test_analyst"] = testAnalystAddr

		err := SetConfig(cfg)
		uassert.NoError(t, err)

		actual := GetCurrentConfig()
		uassert.Equal(t, testManagerAddr, actual.Roles["test_manager"])
		uassert.Equal(t, testAnalystAddr, actual.Roles["test_analyst"])
	})

	t.Run("fail with nil config", func(t *testing.T) {
		err := SetConfig(nil)
		uassert.Error(t, err)
	})
}

func TestSetRole(t *testing.T) {
	testAuditorAddr := testutils.TestAddress("test_auditor")
	testReviewerAddr := testutils.TestAddress("test_reviewer")

	t.Run("success with new role", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		err = SetRole("test_auditor", testAuditorAddr)
		uassert.NoError(t, err)

		actual := GetCurrentConfig()
		uassert.Equal(t, testAuditorAddr, actual.Roles["test_auditor"])

		// verify permission is set correctly
		err = rbac.CheckPermission("test_auditor", PERM_ACCESS, testAuditorAddr)
		uassert.NoError(t, err)
	})

	t.Run("success updating existing role", func(t *testing.T) {
		cfg := DefaultConfig()
		cfg.Roles["test_reviewer"] = testReviewerAddr
		err := Initialize(cfg)
		uassert.NoError(t, err)

		newReviewerAddr := testutils.TestAddress("test_reviewer_new")
		err = SetRole("test_reviewer", newReviewerAddr)
		uassert.NoError(t, err)

		// verify address was updated
		actual := GetCurrentConfig()
		uassert.Equal(t, newReviewerAddr, actual.Roles["test_reviewer"])

		// verify old address cannot access anymore
		err = rbac.CheckPermission("test_reviewer", PERM_ACCESS, testReviewerAddr)
		uassert.Error(t, err)

		// verify new address can access
		err = rbac.CheckPermission("test_reviewer", PERM_ACCESS, newReviewerAddr)
		uassert.NoError(t, err)
	})

	t.Run("fail with empty role name", func(t *testing.T) {
		cfg := DefaultConfig()
		err := Initialize(cfg)
		uassert.NoError(t, err)

		err = SetRole("", testAuditorAddr)
		uassert.Error(t, err)
	})

	t.Run("fail while uninitialized", func(t *testing.T) {
		currentConfig = nil
		err := SetRole("test_auditor", testAuditorAddr)
		uassert.Error(t, err)
	})
}
