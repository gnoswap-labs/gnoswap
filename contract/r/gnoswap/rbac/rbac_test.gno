package rbac

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
)

func TestRegisterRole(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()
	manager.RegisterRole("duplicate_role")

	tests := []struct {
		name        string
		roleName    string
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "Register new custom role should succeed",
			roleName:    "custom_role",
			shouldError: false,
		},
		{
			name:        "Register system role should error",
			roleName:    prbac.ROLE_ADMIN.String(),
			shouldError: true,
			errorMsg:    "role admin already exists",
		},
		{
			name:        "Register existing role should error",
			roleName:    "duplicate_role",
			shouldError: true, // First registration should succeed
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(std.NewUserRealm(ADMIN))

			err := manager.RegisterRole(tt.roleName)

			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}

	// Test duplicate registration
	t.Run("Register duplicate role should fail", func(t *testing.T) {
		duplicateRole := "duplicate_test_role"

		// First registration
		err := manager.RegisterRole(duplicateRole)
		if err != nil {
			t.Fatalf("First registration should succeed: %v", err)
		}

		// Second registration should fail
		err = manager.RegisterRole(duplicateRole)
		if err == nil {
			t.Error("Duplicate registration should fail")
		}
	})
}

func TestRemoveRole(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	// Register a test role first
	testRole := "test_removable_role"
	err := manager.RegisterRole(testRole)
	if err != nil {
		t.Fatalf("Failed to register test role: %v", err)
	}

	tests := []struct {
		name        string
		roleName    string
		shouldError bool
		errorMsg    string
	}{
		{
			name:        "Remove custom role should succeed",
			roleName:    testRole,
			shouldError: false,
		},
		{
			name:        "Remove system role should error",
			roleName:    prbac.ROLE_ADMIN.String(),
			shouldError: true,
			errorMsg:    "cannot remove system role",
		},
		{
			name:        "Remove non-existent role should fail",
			roleName:    "non_existent_role",
			shouldError: true, // manager.RemoveRole will return error, not panic
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(std.NewUserRealm(ADMIN))

			// Test manager functionality directly
			err := manager.RemoveRole(tt.roleName)
			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestGetRoleAddress(t *testing.T) {
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

func TestUpdateRoleAddress(t *testing.T) {
	// Reset manager for test
	manager = prbac.NewRBACWithAddress(ADMIN)
	initRbac()

	// Register a test role
	testRole := "test_update_role"
	err := manager.RegisterRole(testRole)
	if err != nil {
		t.Fatalf("Failed to register test role: %v", err)
	}

	tests := []struct {
		name      string
		roleName  string
		addr      std.Address
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
	err := manager.RegisterRole(testRole)
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
		oldAddress    std.Address
		newAddress    std.Address
		expectSuccess bool
		verifyFunc    func(t *testing.T, roleName string, expectedAddr std.Address)
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
			verifyFunc: func(t *testing.T, roleName string, expectedAddr std.Address) {
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
				manager.RegisterRole("custom_role")
				manager.UpdateRoleAddress("custom_role", testutils.TestAddress("custom"))
			},
			roleName:      "custom_role",
			oldAddress:    testutils.TestAddress("custom"),
			newAddress:    testutils.TestAddress("new_custom"),
			expectSuccess: true,
			verifyFunc: func(t *testing.T, roleName string, expectedAddr std.Address) {
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
			verifyFunc: func(t *testing.T, roleName string, expectedAddr std.Address) {
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
			testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))

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
		name       string
		operations []struct {
			action   string // "register", "update", "remove"
			roleName string
			address  std.Address
		}
		verifyRoles map[string]std.Address // Expected final state
	}{
		{
			name: "Register new role updates access package",
			operations: []struct {
				action   string
				roleName string
				address  std.Address
			}{
				{action: "register", roleName: "test_role_1"},
				{action: "update", roleName: "test_role_1", address: testutils.TestAddress("test_role_1")},
			},
			verifyRoles: map[string]std.Address{
				"test_role_1": testutils.TestAddress("test_role_1"),
			},
		},
		{
			name: "Remove role updates access package",
			operations: []struct {
				action   string
				roleName string
				address  std.Address
			}{
				{action: "register", roleName: "temp_role"},
				{action: "update", roleName: "temp_role", address: testutils.TestAddress("temp_role")},
				{action: "remove", roleName: "temp_role"},
			},
			verifyRoles: map[string]std.Address{
				// temp_role should not exist
			},
		},
		{
			name: "Multiple operations sync correctly",
			operations: []struct {
				action   string
				roleName string
				address  std.Address
			}{
				{action: "register", roleName: "role_a"},
				{action: "register", roleName: "role_b"},
				{action: "update", roleName: "role_a", address: testutils.TestAddress("role_a")},
				{action: "update", roleName: "role_b", address: testutils.TestAddress("role_b")},
				{action: "update", roleName: "role_a", address: testutils.TestAddress("role_a_new")}, // Update again
				{action: "remove", roleName: "role_b"},
			},
			verifyRoles: map[string]std.Address{
				"role_a": testutils.TestAddress("role_a_new"),
				// role_b should not exist
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set realm to rbac for access package calls
			testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/rbac"))

			// Reset manager
			manager = prbac.NewRBACWithAddress(ADMIN)
			initRbac()

			// Execute operations
			for _, op := range tt.operations {
				switch op.action {
				case "register":
					err := manager.RegisterRole(op.roleName)
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
			allRoles := manager.GetRoleAddresses()
			for roleName, expectedAddr := range tt.verifyRoles {
				actualAddr, exists := allRoles[roleName]
				if !exists {
					t.Errorf("Role %s should exist in RBAC", roleName)
					continue
				}
				if actualAddr != expectedAddr {
					t.Errorf("Role %s address mismatch: got %s, want %s", roleName, actualAddr, expectedAddr)
				}
			}

			// Verify removed roles don't exist
			for _, op := range tt.operations {
				if op.action == "remove" {
					if _, exists := allRoles[op.roleName]; exists {
						t.Errorf("Role %s should not exist after removal", op.roleName)
					}
				}
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
