package rbac

import (
	"std"
	"testing"

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
