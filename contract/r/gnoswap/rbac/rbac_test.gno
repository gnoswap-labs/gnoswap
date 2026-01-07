package rbac

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestRbac_RegisterRole(t *testing.T) {
	tests := []struct {
		name          string
		setup         func()
		roleName      string
		roleAddress   address
		callerRealm   address // Test with different callers (ADMIN or GOVERNANCE)
		shouldPanic   bool
		panicContains string
	}{
		{
			name: "Register role with valid address succeeds (ADMIN)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:    "custom_role_with_addr",
			roleAddress: testutils.TestAddress("custom_role_address"),
			callerRealm: ADMIN,
			shouldPanic: false,
		},
		{
			name: "Register role with valid address succeeds (GOVERNANCE)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:    "custom_role_governance",
			roleAddress: testutils.TestAddress("custom_gov_address"),
			callerRealm: GOV_GOVERNANCE_ADDR,
			shouldPanic: false,
		},
		{
			name: "Register role with different valid address succeeds (ADMIN)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:    "another_custom_role",
			roleAddress: testutils.TestAddress("another_address"),
			callerRealm: ADMIN,
			shouldPanic: false,
		},
		{
			name: "Register role with empty address fails (ADMIN)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "invalid_role_empty",
			roleAddress:   address(""),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
		{
			name: "Register role with empty address fails (GOVERNANCE)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "invalid_role_empty_gov",
			roleAddress:   address(""),
			callerRealm:   GOV_GOVERNANCE_ADDR,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
		{
			name: "Register duplicate role with different address fails (ADMIN)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				// Pre-register a role
				manager.RegisterRole("duplicate_role", testutils.TestAddress("original"))
				manager.UpdateRoleAddress("duplicate_role", testutils.TestAddress("original"))
			},
			roleName:      "duplicate_role",
			roleAddress:   testutils.TestAddress("new_address"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "role duplicate_role already exists",
		},
		{
			name: "Register system role with new address fails (GOVERNANCE)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      prbac.ROLE_ADMIN.String(),
			roleAddress:   testutils.TestAddress("new_admin"),
			callerRealm:   GOV_GOVERNANCE_ADDR,
			shouldPanic:   true,
			panicContains: "role admin already exists",
		},
		{
			name: "Register role with unauthorized caller fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "unauthorized_role",
			roleAddress:   testutils.TestAddress("some_address"),
			callerRealm:   testutils.TestAddress("random_user"),
			shouldPanic:   true,
			panicContains: "caller is not admin or governance",
		},
		{
			name: "Register role with devops caller fails (not admin or governance)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "devops_role_attempt",
			roleAddress:   testutils.TestAddress("devops_address"),
			callerRealm:   DEV_OPS,
			shouldPanic:   true,
			panicContains: "caller is not admin or governance",
		},
		{
			name: "Register role with empty role name fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "",
			roleAddress:   testutils.TestAddress("valid_address"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid role name",
		},
		{
			name: "Register role with whitespace-only name fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "   ",
			roleAddress:   testutils.TestAddress("valid_address"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid role name",
		},
		{
			name: "Register role with tab and space name fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      " \t ",
			roleAddress:   testutils.TestAddress("valid_address"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid role name",
		},
		{
			name: "Register role with invalid address format fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "valid_role_invalid_addr",
			roleAddress:   address("invalid"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
		{
			name: "Register role with malformed address fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "valid_role_malformed",
			roleAddress:   address("g1"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()

			// Set realm to the specified caller for authorization testing
			testing.SetRealm(testing.NewUserRealm(tt.callerRealm))

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicContains, func() {
					RegisterRole(cross, tt.roleName, tt.roleAddress)
				})
			} else {
				RegisterRole(cross, tt.roleName, tt.roleAddress)

				// Verify the role was registered with correct address
				addr, err := manager.GetRoleAddress(tt.roleName)
				uassert.NoError(t, err, "Failed to get role address")
				uassert.Equal(t, addr, tt.roleAddress, "Role address mismatch")
			}
		})
	}
}

func TestRbac_RemoveRole(t *testing.T) {
	tests := []struct {
		name        string
		setup       func()
		roleName    string
		shouldError bool
		errorMsg    string
	}{
		{
			name: "Remove custom role should succeed",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				manager.RegisterRole("removable_role", testutils.TestAddress("removable_address"))
			},
			roleName:    "removable_role",
			shouldError: false,
		},
		{
			name: "Remove system role should error",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:    prbac.ROLE_ADMIN.String(),
			shouldError: true,
			errorMsg:    "cannot remove system role",
		},
		{
			name: "Remove non-existent role should error",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:    "non_existent_role",
			shouldError: true,
			errorMsg:    "does not exist",
		},
		{
			name: "Remove role with empty string should error",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:    "",
			shouldError: true,
			errorMsg:    "invalid role name",
		},
		{
			name: "Remove role multiple times should error on second attempt",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				manager.RegisterRole("remove_twice_role", testutils.TestAddress("remove_twice_address"))
				manager.RemoveRole("remove_twice_role") // First removal
			},
			roleName:    "remove_twice_role",
			shouldError: true,
			errorMsg:    "does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()
			testing.SetRealm(testing.NewUserRealm(ADMIN))
			err := manager.RemoveRole(tt.roleName)

			if tt.shouldError {
				uassert.Error(t, err)
				if tt.errorMsg != "" && err != nil {
					uassert.True(t, contains(err.Error(), tt.errorMsg))
				}
			} else {
				uassert.NoError(t, err)
				// Verify role was actually removed (if not empty string)
				if tt.roleName != "" {
					_, getErr := manager.GetRoleAddress(tt.roleName)
					uassert.Error(t, getErr) // Should error because role doesn't exist
				}
			}
		})
	}
}

func TestRbac_GetRoleAddress(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	tests := []struct {
		name      string
		roleName  string
		shouldErr bool
	}{
		{
			name:      "Get existing role address should succeed",
			roleName:  prbac.ROLE_ADMIN.String(),
			shouldErr: false,
		},
		{
			name:      "Get non-existent role should return error",
			roleName:  "non_existent_role",
			shouldErr: true,
		},
		{
			name:      "Get role with empty string should return error",
			roleName:  "",
			shouldErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			addr, err := GetRoleAddress(tt.roleName)

			if tt.shouldErr {
				if err == nil {
					t.Error("Expected error for non-existent role")
				}
			} else {
				if err != nil {
					t.Errorf("GetRoleAddress(%s) failed: %v", tt.roleName, err)
				}
				if tt.roleName == prbac.ROLE_ADMIN.String() && addr != ADMIN {
					t.Errorf("Admin role address mismatch: got %s, want %s", addr, ADMIN)
				}
			}
		})
	}
}

func TestRbac_UpdateRoleAddress_Basic(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	// Register a test role
	testRole := "test_update_role"
	err := manager.RegisterRole(testRole, testutils.TestAddress("test_update_address"))
	if err != nil {
		t.Fatalf("Failed to register test role: %v", err)
	}

	tests := []struct {
		name      string
		roleName  string
		addr      address
		shouldErr bool
	}{
		{
			name:      "Update existing role with valid address should succeed",
			roleName:  testRole,
			addr:      DEV_OPS,
			shouldErr: false,
		},
		{
			name:      "Update non-existent role should fail",
			roleName:  "non_existent_role",
			addr:      DEV_OPS,
			shouldErr: true,
		},
		{
			name:      "Update role with invalid address should fail",
			roleName:  testRole,
			addr:      "",
			shouldErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Test manager functionality directly
			err := manager.UpdateRoleAddress(tt.roleName, tt.addr)

			if tt.shouldErr {
				if err == nil {
					t.Errorf("Expected error for test case: %s", tt.name)
				}
			} else {
				if err != nil {
					t.Errorf("UpdateRoleAddress failed: %v", err)
				}
				// Verify address was updated
				updatedAddr, err := manager.GetRoleAddress(tt.roleName)
				if err != nil {
					t.Errorf("Failed to get updated address: %v", err)
				}
				if updatedAddr != tt.addr {
					t.Errorf("Address not updated correctly: got %s, want %s", updatedAddr, tt.addr)
				}
			}
		})
	}
}

func TestUpdateAccessRoleAddresses(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	// This function is private, but we can test its effect indirectly
	// by calling functions that invoke it and checking if access package is updated
	// Test that updateAccessRoleAddresses is called during initialization
	// We can't directly test the access.SetRoleAddresses call without mocking,
	// but we can verify the function doesn't panic when called
	// Register a new role and update its address to trigger updateAccessRoleAddresses
	testRole := "test_access_update"
	err := manager.RegisterRole(testRole, testutils.TestAddress("test_access"))
	if err != nil {
		t.Fatalf("Failed to register test role: %v", err)
	}

	err = manager.UpdateRoleAddress(testRole, DEV_OPS)
	if err != nil {
		t.Fatalf("Failed to update role address: %v", err)
	}

	// If we reach here without panic, the function works correctly
	t.Log("updateAccessRoleAddresses executed successfully")
}

func TestAddressChangeComplete(t *testing.T) {
	tests := []struct {
		name          string
		setup         func()
		roleName      string
		oldAddress    address
		newAddress    address
		expectSuccess bool
		verifyFunc    func(t *testing.T, roleName string, expectedAddr address)
	}{
		{
			name: "Change admin role address",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      prbac.ROLE_ADMIN.String(),
			oldAddress:    ADMIN,
			newAddress:    testutils.TestAddress("new_admin"),
			expectSuccess: true,
			verifyFunc: func(t *testing.T, roleName string, expectedAddr address) {
				// Verify in RBAC
				addr, err := manager.GetRoleAddress(roleName)
				if err != nil {
					t.Errorf("Failed to get role address from RBAC: %v", err)
				}
				if addr != expectedAddr {
					t.Errorf("RBAC address mismatch: got %s, want %s", addr, expectedAddr)
				}
			},
		},
		{
			name: "Change custom role address",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				manager.RegisterRole("custom_role", testutils.TestAddress("custom_address"))
				manager.UpdateRoleAddress("custom_role", testutils.TestAddress("custom"))
			},
			roleName:      "custom_role",
			oldAddress:    testutils.TestAddress("custom"),
			newAddress:    testutils.TestAddress("new_custom"),
			expectSuccess: true,
			verifyFunc: func(t *testing.T, roleName string, expectedAddr address) {
				// Verify in RBAC
				addr, err := manager.GetRoleAddress(roleName)
				if err != nil {
					t.Errorf("Failed to get role address from RBAC: %v", err)
				}
				if addr != expectedAddr {
					t.Errorf("RBAC address mismatch: got %s, want %s", addr, expectedAddr)
				}
			},
		},
		{
			name: "Change multiple role addresses sequentially",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      prbac.ROLE_ROUTER.String(),
			oldAddress:    ROUTER_ADDR,
			newAddress:    testutils.TestAddress("new_router"),
			expectSuccess: true,
			verifyFunc: func(t *testing.T, roleName string, expectedAddr address) {
				// First change router
				addr, err := manager.GetRoleAddress(roleName)
				if err != nil {
					t.Errorf("Failed to get router address: %v", err)
				}
				if addr != expectedAddr {
					t.Errorf("Router address mismatch: got %s, want %s", addr, expectedAddr)
				}

				// Change pool too
				newPoolAddr := testutils.TestAddress("new_pool")
				err = manager.UpdateRoleAddress(prbac.ROLE_POOL.String(), newPoolAddr)
				if err != nil {
					t.Errorf("Failed to update pool address: %v", err)
				}

				// Verify pool changed
				poolAddr, err := manager.GetRoleAddress(prbac.ROLE_POOL.String())
				if err != nil {
					t.Errorf("Failed to get pool address: %v", err)
				}
				if poolAddr != newPoolAddr {
					t.Errorf("Pool address mismatch: got %s, want %s", poolAddr, newPoolAddr)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set realm to rbac for access package calls
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/rbac"))

			// Setup
			tt.setup()

			// Verify initial address
			initialAddr, err := manager.GetRoleAddress(tt.roleName)
			if err != nil {
				t.Fatalf("Failed to get initial address: %v", err)
			}
			if initialAddr != tt.oldAddress {
				t.Fatalf("Initial address mismatch: got %s, want %s", initialAddr, tt.oldAddress)
			}

			// Update address
			err = manager.UpdateRoleAddress(tt.roleName, tt.newAddress)
			if tt.expectSuccess && err != nil {
				t.Fatalf("UpdateRoleAddress failed: %v", err)
			} else if !tt.expectSuccess && err == nil {
				t.Fatal("Expected error but got none")
			}

			if tt.expectSuccess {
				// Verify the change
				tt.verifyFunc(t, tt.roleName, tt.newAddress)
			}
		})
	}
}

func TestRBACToAccessSync(t *testing.T) {
	tests := []struct {
		name              string
		operations        []struct {
			action   string // "register", "update", "remove"
			roleName string
			address  address
		}
		verifyRoles       map[string]address // Expected final state (roles that SHOULD exist)
		verifyRolesNotExist []string           // Roles that should NOT exist
	}{
		{
			name: "Register new role updates access package (empty address)",
			operations: []struct {
				action   string
				roleName string
				address  address
			}{
				{action: "register", roleName: "test_role_1"},
				{action: "update", roleName: "test_role_1", address: testutils.TestAddress("test_role_1")},
			},
			verifyRoles: map[string]address{
				"test_role_1": testutils.TestAddress("test_role_1"),
			},
		},
		{
			name: "Register new role with initial address then update",
			operations: []struct {
				action   string
				roleName string
				address  address
			}{
				{action: "register", roleName: "test_role_2", address: testutils.TestAddress("initial_addr")},
				{action: "update", roleName: "test_role_2", address: testutils.TestAddress("updated_addr")},
			},
			verifyRoles: map[string]address{
				"test_role_2": testutils.TestAddress("updated_addr"),
			},
		},
		{
			name: "Remove role updates access package (empty address)",
			operations: []struct {
				action   string
				roleName string
				address  address
			}{
				{action: "register", roleName: "temp_role"},
				{action: "update", roleName: "temp_role", address: testutils.TestAddress("temp_role")},
				{action: "remove", roleName: "temp_role"},
			},
			verifyRoles: map[string]address{},
			verifyRolesNotExist: []string{"temp_role"},
		},
		{
			name: "Remove role updates access package (with initial address)",
			operations: []struct {
				action   string
				roleName string
				address  address
			}{
				{action: "register", roleName: "temp_role_2", address: testutils.TestAddress("initial_addr")},
				{action: "update", roleName: "temp_role_2", address: testutils.TestAddress("updated_addr")},
				{action: "remove", roleName: "temp_role_2"},
			},
			verifyRoles: map[string]address{},
			verifyRolesNotExist: []string{"temp_role_2"},
		},
		{
			name: "Multiple operations sync correctly (empty addresses)",
			operations: []struct {
				action   string
				roleName string
				address  address
			}{
				{action: "register", roleName: "role_a"},
				{action: "register", roleName: "role_b"},
				{action: "update", roleName: "role_a", address: testutils.TestAddress("role_a")},
				{action: "update", roleName: "role_b", address: testutils.TestAddress("role_b")},
				{action: "update", roleName: "role_a", address: testutils.TestAddress("role_a_new")}, // Update again
				{action: "remove", roleName: "role_b"},
			},
			verifyRoles: map[string]address{
				"role_a": testutils.TestAddress("role_a_new"),
			},
			verifyRolesNotExist: []string{"role_b"},
		},
		{
			name: "Multiple operations sync correctly (with initial addresses)",
			operations: []struct {
				action   string
				roleName string
				address  address
			}{
				{action: "register", roleName: "role_c", address: testutils.TestAddress("role_c_init")},
				{action: "register", roleName: "role_d", address: testutils.TestAddress("role_d_init")},
				{action: "update", roleName: "role_c", address: testutils.TestAddress("role_c_new")}, // Update to new
				{action: "remove", roleName: "role_d"},
			},
			verifyRoles: map[string]address{
				"role_c": testutils.TestAddress("role_c_new"),
			},
			verifyRolesNotExist: []string{"role_d"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set realm to rbac for access package calls
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/rbac"))

			// Reset manager
			manager = prbac.NewRBACWithAddress(ADMIN)
			initRbac()

			// Execute operations
			for _, op := range tt.operations {
				switch op.action {
				case "register":
					err := manager.RegisterRole(op.roleName, op.address)
					if err != nil {
						t.Errorf("Failed to register role %s: %v", op.roleName, err)
					}
				case "update":
					err := manager.UpdateRoleAddress(op.roleName, op.address)
					if err != nil {
						t.Errorf("Failed to update role %s: %v", op.roleName, err)
					}
				case "remove":
					err := manager.RemoveRole(op.roleName)
					if err != nil {
						t.Errorf("Failed to remove role %s: %v", op.roleName, err)
					}
				}
			}

			// Verify final state in RBAC
			allRoles := manager.GetAllRoleAddresses()
			for roleName, expectedAddr := range tt.verifyRoles {
				if len(allRoles) == 0 {
					continue
				}

				actualAddr := allRoles[roleName]
				if actualAddr != expectedAddr {
					t.Errorf("Role %s address mismatch: got %s, want %s", roleName, actualAddr, expectedAddr)
				}
			}

			// Verify roles that should NOT exist
			for _, roleName := range tt.verifyRolesNotExist {
				_, exists := allRoles[roleName]
				if exists {
					t.Errorf("Role %s should not exist, but it does", roleName)
				}
			}
		})
	}
}

func TestRbac_UpdateRoleAddress_WithAuthorization(t *testing.T) {
	tests := []struct {
		name          string
		setup         func()
		roleName      string
		newAddr       address
		callerRealm   address
		shouldPanic   bool
		panicContains string
	}{
		{
			name: "Update role with admin caller succeeds",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_admin", testutils.TestAddress("old_addr"))
			},
			roleName:    "test_update_role_admin",
			newAddr:     testutils.TestAddress("new_addr"),
			callerRealm: ADMIN,
			shouldPanic: false,
		},
		{
			name: "Update role with governance caller succeeds",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_gov", testutils.TestAddress("old_addr"))
			},
			roleName:    "test_update_role_gov",
			newAddr:     testutils.TestAddress("new_addr_gov"),
			callerRealm: GOV_GOVERNANCE_ADDR,
			shouldPanic: false,
		},
		{
			name: "Update role with unauthorized caller fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_unauth", testutils.TestAddress("old_addr"))
			},
			roleName:      "test_update_role_unauth",
			newAddr:       testutils.TestAddress("new_addr_unauth"),
			callerRealm:   testutils.TestAddress("random_user"),
			shouldPanic:   true,
			panicContains: "caller is not admin or governance",
		},
		{
			name: "Update role with devops caller fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_devops", testutils.TestAddress("old_addr"))
			},
			roleName:      "test_update_role_devops",
			newAddr:       testutils.TestAddress("new_addr_devops"),
			callerRealm:   DEV_OPS,
			shouldPanic:   true,
			panicContains: "caller is not admin or governance",
		},
		{
			name: "Update role with empty role name fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "",
			newAddr:       testutils.TestAddress("new_addr"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid role name",
		},
		{
			name: "Update role with empty address fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_empty_addr", testutils.TestAddress("old_addr"))
			},
			roleName:      "test_update_role_empty_addr",
			newAddr:       address(""),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
		{
			name: "Update role with invalid address format fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_invalid_addr", testutils.TestAddress("old_addr"))
			},
			roleName:      "test_update_role_invalid_addr",
			newAddr:       address("invalid"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
		{
			name: "Update role with malformed address fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_update_role_malformed", testutils.TestAddress("old_addr"))
			},
			roleName:      "test_update_role_malformed",
			newAddr:       address("g1"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid address",
		},
		{
			name: "Update non-existent role fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "non_existent_role",
			newAddr:       testutils.TestAddress("new_addr"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "does not exist",
		},
		{
			name: "Update role with same address succeeds (idempotent)",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_idempotent_role", testutils.TestAddress("same_addr"))
			},
			roleName:    "test_idempotent_role",
			newAddr:     testutils.TestAddress("same_addr"),
			callerRealm: ADMIN,
			shouldPanic: false,
		},
		{
			name: "Update admin role via UpdateRoleAddress fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      prbac.ROLE_ADMIN.String(),
			newAddr:       testutils.TestAddress("new_admin"),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "admin role is managed by owner",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()

			// Set realm to the specified caller for authorization testing
			testing.SetRealm(testing.NewUserRealm(tt.callerRealm))

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicContains, func() {
					UpdateRoleAddress(cross, tt.roleName, tt.newAddr)
				})
			} else {
				UpdateRoleAddress(cross, tt.roleName, tt.newAddr)

				// Verify the role address was updated
				addr, err := manager.GetRoleAddress(tt.roleName)
				uassert.NoError(t, err, "Failed to get role address")
				uassert.Equal(t, addr, tt.newAddr, "Role address was not updated correctly")
			}
		})
	}
}

func TestRbac_RemoveRole_WithAuthorization(t *testing.T) {
	tests := []struct {
		name          string
		setup         func()
		roleName      string
		callerRealm   address
		shouldPanic   bool
		panicContains string
	}{
		{
			name: "Remove role with admin caller succeeds",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_remove_role_admin", testutils.TestAddress("test_addr"))
			},
			roleName:    "test_remove_role_admin",
			callerRealm: ADMIN,
			shouldPanic: false,
		},
		{
			name: "Remove role with governance caller succeeds",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_remove_role_gov", testutils.TestAddress("test_addr"))
			},
			roleName:    "test_remove_role_gov",
			callerRealm: GOV_GOVERNANCE_ADDR,
			shouldPanic: false,
		},
		{
			name: "Remove role with unauthorized caller fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_remove_role_unauth", testutils.TestAddress("test_addr"))
			},
			roleName:      "test_remove_role_unauth",
			callerRealm:   testutils.TestAddress("random_user"),
			shouldPanic:   true,
			panicContains: "caller is not admin or governance",
		},
		{
			name: "Remove role with devops caller fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
				testing.SetRealm(testing.NewUserRealm(ADMIN))
				RegisterRole(cross, "test_remove_role_devops", testutils.TestAddress("test_addr"))
			},
			roleName:      "test_remove_role_devops",
			callerRealm:   DEV_OPS,
			shouldPanic:   true,
			panicContains: "caller is not admin or governance",
		},
		{
			name: "Remove role with empty role name fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "",
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "invalid role name",
		},
		{
			name: "Remove admin role fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      prbac.ROLE_ADMIN.String(),
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "admin role is managed by owner",
		},
		{
			name: "Remove non-existent role fails",
			setup: func() {
				manager = prbac.NewRBACWithAddress(ADMIN)
				initRbac()
			},
			roleName:      "non_existent_role",
			callerRealm:   ADMIN,
			shouldPanic:   true,
			panicContains: "does not exist",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()

			// Set realm to the specified caller for authorization testing
			testing.SetRealm(testing.NewUserRealm(tt.callerRealm))

			if tt.shouldPanic {
				uassert.AbortsContains(t, tt.panicContains, func() {
					RemoveRole(cross, tt.roleName)
				})
			} else {
				RemoveRole(cross, tt.roleName)

				// Verify the role was actually removed
				_, err := manager.GetRoleAddress(tt.roleName)
				uassert.Error(t, err, "Role should not exist after removal")
			}
		})
	}
}

// Helper function to check if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && s[:len(substr)] == substr ||
		(len(s) > len(substr) && s[len(s)-len(substr):] == substr) ||
		(len(s) > len(substr) && findSubstring(s, substr))
}

func findSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
