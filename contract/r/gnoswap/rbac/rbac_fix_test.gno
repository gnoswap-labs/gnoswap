package rbac

import (
	"std"
	"testing"

	"gno.land/p/nt/testutils"

	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/access"
)

// TestRegisterRoleNoLongerPanics verifies that RegisterRole no longer panics
// after the fix to filter empty addresses during synchronization
func TestRegisterRoleNoLongerPanics(t *testing.T) {
	// Save the original manager state
	originalManager := manager
	defer func() {
		manager = originalManager
	}()

	// Reset RBAC state for clean test
	initRbac()

	// Set the previous realm to admin to pass permission check
	testing.SetRealm(std.NewUserRealm(ADMIN))

	// This should NOT panic after the fix
	RegisterRole(cross, "NEW_TEST_ROLE")

	// Verify the role was created
	addr, err := GetRoleAddress("NEW_TEST_ROLE")
	uassert.NoError(t, err, "Should be able to get the new role")
	uassert.Equal(t, "", addr.String(), "New role should have empty address")

	// Verify the role is NOT in access package (since it has empty address)
	accessAddresses := access.GetRoleAddresses()
	_, exists := accessAddresses["NEW_TEST_ROLE"]
	uassert.False(t, exists, "Role with empty address should not be in access package")
}

// TestRegisterAndUpdateRoleFlow verifies the complete flow works correctly
func TestRegisterAndUpdateRoleFlow(t *testing.T) {
	// Save the original manager state
	originalManager := manager
	defer func() {
		manager = originalManager
	}()

	// Reset RBAC state for clean test
	initRbac()

	// Set the previous realm to admin to pass permission check
	testing.SetRealm(std.NewUserRealm(ADMIN))

	// Step 1: Register a new role (should not panic)
	RegisterRole(cross, "TEST_ROLE")

	// Verify role is created with empty address
	addr, err := GetRoleAddress("TEST_ROLE")
	uassert.NoError(t, err, "Should be able to get the new role")
	uassert.Equal(t, "", addr.String(), "New role should have empty address")

	// Verify role is NOT in access package yet
	accessAddresses := access.GetRoleAddresses()
	_, exists := accessAddresses["TEST_ROLE"]
	uassert.False(t, exists, "Role with empty address should not be in access package")

	// Step 2: Update the role with a valid address
	testAddr := testutils.TestAddress("TEST_ROLE")
	UpdateRoleAddress(cross, "TEST_ROLE", testAddr)

	// Verify role now has the address
	addr, err = GetRoleAddress("TEST_ROLE")
	uassert.NoError(t, err, "Should be able to get the role")
	uassert.Equal(t, testAddr.String(), addr.String(), "Role should have the updated address")

	// Verify role is NOW in access package
	accessAddresses = access.GetRoleAddresses()
	accessAddr, exists := accessAddresses["TEST_ROLE"]
	uassert.True(t, exists, "Role with valid address should be in access package")
	uassert.Equal(t, testAddr.String(), accessAddr.String(), "Access package should have correct address")
}

// TestExistingRolesNotAffected verifies that existing roles with valid addresses
// are not affected by the filtering logic
func TestExistingRolesNotAffected(t *testing.T) {
	// Save the original manager state
	originalManager := manager
	defer func() {
		manager = originalManager
	}()

	// Reset RBAC state for clean test
	initRbac()

	// Get initial role count in access package
	initialAccessRoles := access.GetRoleAddresses()
	initialCount := len(initialAccessRoles)

	// Set the previous realm to admin to pass permission check
	testing.SetRealm(std.NewUserRealm(ADMIN))

	// Register a new role with empty address
	RegisterRole(cross, "EMPTY_ROLE")

	// Verify existing roles are still in access package
	currentAccessRoles := access.GetRoleAddresses()

	// The count should remain the same (new empty role not added)
	uassert.Equal(t, initialCount, len(currentAccessRoles), "Access role count should not change")

	// Verify all initial roles are still present
	for role, addr := range initialAccessRoles {
		currentAddr, exists := currentAccessRoles[role]
		uassert.True(t, exists, "Existing role should still exist: "+role)
		uassert.Equal(t, addr.String(), currentAddr.String(), "Existing role address should not change: "+role)
	}
}
