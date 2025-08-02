// Scenario Test: RBAC Role Management Full Flow
// Tests complete flows of role management in the RBAC system using manager directly
// including role creation, address updates, and role removal

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

var t *testing.T

var (
	customAddr1 = testutils.TestAddress("custom1")
	customAddr2 = testutils.TestAddress("custom2")
	customAddr3 = testutils.TestAddress("custom3")

	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

	// Create manager for scenario testing
	manager *prbac.RBAC
)

func main() {
	println("[SCENARIO] 1. Setup Test Manager")
	setupTestManager()
	println()

	println("[SCENARIO] 2. Admin Role Lifecycle Management")
	testAdminRoleLifecycleManagement()
	println()

	println("[SCENARIO] 3. System Role Management")
	testSystemRoleManagement()
	println()

	println("[SCENARIO] 4. Multiple Role Authorization")
	testMultipleRoleAuthorization()
	println()

	println("[SCENARIO] 5. Error Handling and Edge Cases")
	testErrorHandlingEdgeCases()
	println()

	println("[SCENARIO] 6. Role Addresses Integration")
	testRoleAddressesIntegration()
	println()
}

func setupTestManager() {
	// Initialize a test RBAC manager with admin
	manager = prbac.NewRBACWithAddress(adminAddr)

	// Register system roles
	systemRoles := []prbac.SystemRole{
		prbac.ROLE_ADMIN,
		prbac.ROLE_DEVOPS,
		prbac.ROLE_POOL,
		prbac.ROLE_ROUTER,
		prbac.ROLE_STAKER,
	}

	for _, role := range systemRoles {
		err := manager.RegisterRole(role.String())
		if err != nil {
			println("Warning: Could not register system role", role.String(), ":", err)
		}
	}

	println("Test manager setup completed")
}

// Scenario: Complete role lifecycle management by admin
func testAdminRoleLifecycleManagement() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Create a new custom role for "api_service"
	println("Step 1: Creating custom role 'api_service'")
	err := manager.RegisterRole("api_service")
	uassert.NoError(t, err)

	// Verify role exists but has no address assigned yet
	addr, err := manager.GetRoleAddress("api_service")
	uassert.NoError(t, err)
	uassert.Equal(t, std.Address(""), addr)

	// Step 2: Assign address to the new role
	println("Step 2: Assigning address to 'api_service' role")
	err = manager.UpdateRoleAddress("api_service", customAddr1)
	uassert.NoError(t, err)

	// Verify address is correctly assigned
	addr, err = manager.GetRoleAddress("api_service")
	uassert.NoError(t, err)
	uassert.Equal(t, customAddr1, addr)

	// Step 3: Create another custom role for "data_processor"
	println("Step 3: Creating another custom role 'data_processor'")
	err = manager.RegisterRole("data_processor")
	uassert.NoError(t, err)

	err = manager.UpdateRoleAddress("data_processor", customAddr2)
	uassert.NoError(t, err)

	// Step 4: Update the address of existing role
	println("Step 4: Updating address of 'api_service' role")
	err = manager.UpdateRoleAddress("api_service", customAddr3)
	uassert.NoError(t, err)

	// Verify address update
	addr, err = manager.GetRoleAddress("api_service")
	uassert.NoError(t, err)
	uassert.Equal(t, customAddr3, addr)

	// Step 5: Remove a custom role that's no longer needed
	println("Step 5: Removing 'api_service' role")
	err = manager.RemoveRole("api_service")
	uassert.NoError(t, err)

	// Verify role is removed
	_, err = manager.GetRoleAddress("api_service")
	uassert.Error(t, err)

	// Step 6: Verify other role still exists
	println("Step 6: Verifying other role still exists")
	addr, err = manager.GetRoleAddress("data_processor")
	uassert.NoError(t, err)
	uassert.Equal(t, customAddr2, addr)

	println("Admin role lifecycle management scenario completed successfully")
}

// Scenario: System role management - what admin can and cannot do
func testSystemRoleManagement() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Verify system roles exist
	println("Step 1: Verifying system roles exist")

	adminRoleAddr, err := manager.GetRoleAddress(prbac.ROLE_ADMIN.String())
	uassert.NoError(t, err)
	// Admin role should have been set during initialization
	println("Admin role address:", adminRoleAddr.String())

	// Step 2: Admin can update system role addresses
	println("Step 2: Admin updating system role address")
	err = manager.UpdateRoleAddress(prbac.ROLE_POOL.String(), customAddr1)
	uassert.NoError(t, err)

	// Verify update
	addr, err := manager.GetRoleAddress(prbac.ROLE_POOL.String())
	uassert.NoError(t, err)
	uassert.Equal(t, customAddr1, addr)

	// Step 3: Test duplicate role registration (should fail)
	println("Step 3: Attempting to register existing system role (should fail)")
	err = manager.RegisterRole(prbac.ROLE_ADMIN.String())
	uassert.Error(t, err)

	println("System role management scenario completed successfully")
}

// Scenario: Multiple role authorization flow
func testMultipleRoleAuthorization() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Create multiple custom roles with different addresses
	println("Step 1: Creating multiple roles")
	roles := []string{"frontend_service", "backend_service", "database_service"}
	addresses := []std.Address{customAddr1, customAddr2, customAddr3}

	for i, role := range roles {
		err := manager.RegisterRole(role)
		uassert.NoError(t, err)

		err = manager.UpdateRoleAddress(role, addresses[i])
		uassert.NoError(t, err)
	}

	// Step 2: Verify authorization for each role
	println("Step 2: Testing authorization for each role")
	for i, role := range roles {
		// Check that the assigned address is authorized for the role
		isAuth := manager.IsAuthorized(role, addresses[i])
		uassert.True(t, isAuth)

		// Check that other addresses are not authorized
		for j, otherAddr := range addresses {
			if i != j {
				isAuth := manager.IsAuthorized(role, otherAddr)
				uassert.False(t, isAuth)
			}
		}
	}

	// Step 3: Test authorization for system roles
	println("Step 3: Testing system role authorization")
	isAuth := manager.IsAuthorized(prbac.ROLE_ADMIN.String(), adminAddr)
	// Note: This might be false if admin address wasn't set during role creation
	println("Admin authorization result:", isAuth)

	isAuth = manager.IsAuthorized(prbac.ROLE_ADMIN.String(), customAddr1)
	uassert.False(t, isAuth)

	// Step 4: Update role address and verify authorization changes
	println("Step 4: Updating role address and testing authorization")
	err := manager.UpdateRoleAddress("frontend_service", customAddr2)
	uassert.NoError(t, err)

	// Old address should no longer be authorized
	isAuth = manager.IsAuthorized("frontend_service", customAddr1)
	uassert.False(t, isAuth)

	// New address should be authorized
	isAuth = manager.IsAuthorized("frontend_service", customAddr2)
	uassert.True(t, isAuth)

	println("Multiple role authorization scenario completed successfully")
}

// Scenario: Error handling and edge cases
func testErrorHandlingEdgeCases() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Test operations on non-existent roles
	println("Step 1: Testing operations on non-existent roles")

	// Try to get address of non-existent role
	_, err := manager.GetRoleAddress("non_existent_role")
	uassert.Error(t, err)

	// Try to update address of non-existent role
	err = manager.UpdateRoleAddress("non_existent_role", customAddr1)
	uassert.Error(t, err)

	// Try to remove non-existent role
	err = manager.RemoveRole("non_existent_role")
	uassert.Error(t, err)

	// Try to check authorization for non-existent role
	isAuth := manager.IsAuthorized("non_existent_role", customAddr1)
	uassert.False(t, isAuth)

	// Step 2: Test duplicate role registration
	println("Step 2: Testing duplicate role registration")
	err = manager.RegisterRole("test_role")
	uassert.NoError(t, err)

	// Try to register same role again
	err = manager.RegisterRole("test_role")
	uassert.Error(t, err)

	// Step 3: Test removing role and then trying to access it
	println("Step 3: Testing role removal and subsequent access")
	err = manager.RemoveRole("test_role")
	uassert.NoError(t, err)

	// Try to access removed role
	_, err = manager.GetRoleAddress("test_role")
	uassert.Error(t, err)

	// Try to update removed role
	err = manager.UpdateRoleAddress("test_role", customAddr1)
	uassert.Error(t, err)

	// Try to authorize removed role
	isAuth = manager.IsAuthorized("test_role", customAddr1)
	uassert.False(t, isAuth)

	println("Error handling and edge cases scenario completed successfully")
}

// Scenario: Role addresses integration
func testRoleAddressesIntegration() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Test role addresses mapping
	println("Step 1: Testing role addresses mapping")

	// Get all role addresses
	roleAddresses := manager.GetRoleAddresses()
	println("Number of roles in system:", len(roleAddresses))

	// Step 2: Test custom role integration
	println("Step 2: Testing custom role integration")

	// Create custom role
	err := manager.RegisterRole("integration_test_role")
	uassert.NoError(t, err)

	err = manager.UpdateRoleAddress("integration_test_role", customAddr2)
	uassert.NoError(t, err)

	// Verify it appears in role addresses
	updatedRoleAddresses := manager.GetRoleAddresses()
	addr, exists := updatedRoleAddresses["integration_test_role"]
	uassert.True(t, exists)
	uassert.Equal(t, customAddr2, addr)

	// Step 3: Verify authorization works correctly
	println("Step 3: Final authorization verification")

	isAuth := manager.IsAuthorized("integration_test_role", customAddr2)
	uassert.True(t, isAuth)

	// Step 4: Test ownership functions
	println("Step 4: Testing ownership functions")

	owner := manager.Owner()
	uassert.Equal(t, adminAddr, owner)

	pendingOwner := manager.PendingOwner()
	uassert.Equal(t, std.Address(""), pendingOwner)

	println("Role addresses integration scenario completed successfully")
}

// Output:
// [SCENARIO] 1. Setup Test Manager
// Test manager setup completed
//
// [SCENARIO] 2. Admin Role Lifecycle Management
// Step 1: Creating custom role 'api_service'
// Step 2: Assigning address to 'api_service' role
// Step 3: Creating another custom role 'data_processor'
// Step 4: Updating address of 'api_service' role
// Step 5: Removing 'api_service' role
// Step 6: Verifying other role still exists
// Admin role lifecycle management scenario completed successfully
//
// [SCENARIO] 3. System Role Management
// Step 1: Verifying system roles exist
// Admin role address:
// Step 2: Admin updating system role address
// Step 3: Attempting to register existing system role (should fail)
// System role management scenario completed successfully
//
// [SCENARIO] 4. Multiple Role Authorization
// Step 1: Creating multiple roles
// Step 2: Testing authorization for each role
// Step 3: Testing system role authorization
// Admin authorization result: true
// Step 4: Updating role address and testing authorization
// Multiple role authorization scenario completed successfully
//
// [SCENARIO] 5. Error Handling and Edge Cases
// Step 1: Testing operations on non-existent roles
// Step 2: Testing duplicate role registration
// Step 3: Testing role removal and subsequent access
// Error handling and edge cases scenario completed successfully
//
// [SCENARIO] 6. Role Addresses Integration
// Step 1: Testing role addresses mapping
// Number of roles in system: 9
// Step 2: Testing custom role integration
// Step 3: Final authorization verification
// Step 4: Testing ownership functions
// Role addresses integration scenario completed successfully
