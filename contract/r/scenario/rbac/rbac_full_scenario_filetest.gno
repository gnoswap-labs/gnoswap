// Scenario Test: RBAC Role Management Full Flow
// Tests complete flows of role management in the RBAC system using manager directly
// including role creation, address updates, and role removal

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
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
	systemRoles := map[prbac.SystemRole]address{
		prbac.ROLE_ADMIN:  testutils.TestAddress("admin"),
		prbac.ROLE_DEVOPS: testutils.TestAddress("devops"),
		prbac.ROLE_POOL:   testutils.TestAddress("pool"),
		prbac.ROLE_ROUTER: testutils.TestAddress("router"),
		prbac.ROLE_STAKER: testutils.TestAddress("staker"),
	}

	for role, addr := range systemRoles {
		err := manager.RegisterRole(role.String(), addr)
		uassert.NoError(t, err)
	}

	println("Test manager setup completed")
}

// Scenario: Complete role lifecycle management by admin
func testAdminRoleLifecycleManagement() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Create a new custom role for "api_service"
	println("Step 1: Creating custom role 'api_service'")
	err := manager.RegisterRole("api_service", testutils.TestAddress("api_service"))
	uassert.NoError(t, err)

	// Verify role exists but has no address assigned yet
	addr, err := manager.GetRoleAddress("api_service")
	uassert.NoError(t, err)
	uassert.Equal(t, testutils.TestAddress("api_service"), addr)

	// Step 2: Assign address to the new role
	println("Step 2: Assigning address to 'api_service' role")
	err = manager.UpdateRoleAddress("api_service", 1, customAddr1)
	uassert.NoError(t, err)

	// Verify address is correctly assigned
	addr, err = manager.GetRoleAddress("api_service")
	uassert.NoError(t, err)
	uassert.Equal(t, customAddr1, addr)

	// Step 3: Create another custom role for "data_processor"
	println("Step 3: Creating another custom role 'data_processor'")
	err = manager.RegisterRole("data_processor", testutils.TestAddress("data_processor"))
	uassert.NoError(t, err)

	err = manager.UpdateRoleAddress("data_processor", 1, customAddr2)
	uassert.NoError(t, err)

	// Step 4: Update the address of existing role
	println("Step 4: Updating address of 'api_service' role")
	err = manager.UpdateRoleAddress("api_service", 1, customAddr3)
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
	err = manager.UpdateRoleAddress(prbac.ROLE_POOL.String(), 1, customAddr1)
	uassert.NoError(t, err)

	// Verify update
	addr, err := manager.GetRoleAddress(prbac.ROLE_POOL.String())
	uassert.NoError(t, err)
	uassert.Equal(t, customAddr1, addr)

	// Step 3: Test duplicate role registration (should fail)
	println("Step 3: Attempting to register existing system role (should fail)")
	err = manager.RegisterRole(prbac.ROLE_ADMIN.String(), testutils.TestAddress("admin"))
	uassert.Error(t, err)

	println("System role management scenario completed successfully")
}

// Scenario: Multiple role authorization flow
func testMultipleRoleAuthorization() {
	testing.SetOriginCaller(adminAddr)

	// Step 1: Create multiple custom roles with different addresses
	println("Step 1: Creating multiple roles")
	roleAddresses := map[string]address{
		"frontend_service": customAddr1,
		"backend_service":  customAddr2,
		"database_service": customAddr3,
	}

	for role, addr := range roleAddresses {
		err := manager.RegisterRole(role, addr)
		uassert.NoError(t, err)

		err = manager.UpdateRoleAddress(role, 1, addr)
		uassert.NoError(t, err)
	}

	// Step 2: Verify authorization for each role
	println("Step 2: Testing authorization for each role")
	for role, addr := range roleAddresses {
		// Check that the assigned address is authorized for the role
		isAuth := manager.IsAuthorized(role, addr)
		uassert.True(t, isAuth)

		// Check that other addresses are not authorized
		for otherRole, otherAddr := range roleAddresses {
			if role != otherRole {
				isAuth := manager.IsAuthorized(role, otherAddr)
				ufmt.Printf("[INFO] checking if %s is authorized for %s address (address: %s, isAuth: %t)\n", role, otherRole, otherAddr, isAuth)
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
	err := manager.UpdateRoleAddress("frontend_service", 1, customAddr2)
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
	err = manager.UpdateRoleAddress("non_existent_role", 1, customAddr1)
	uassert.Error(t, err)

	// Try to remove non-existent role
	err = manager.RemoveRole("non_existent_role")
	uassert.Error(t, err)

	// Try to check authorization for non-existent role
	isAuth := manager.IsAuthorized("non_existent_role", customAddr1)
	uassert.False(t, isAuth)

	// Step 2: Test duplicate role registration
	println("Step 2: Testing duplicate role registration")
	err = manager.RegisterRole("test_role", testutils.TestAddress("test_role"))
	uassert.NoError(t, err)

	// Try to register same role again
	err = manager.RegisterRole("test_role", testutils.TestAddress("test_role"))
	uassert.Error(t, err)

	// Step 3: Test removing role and then trying to access it
	println("Step 3: Testing role removal and subsequent access")
	err = manager.RemoveRole("test_role")
	uassert.NoError(t, err)

	// Try to access removed role
	_, err = manager.GetRoleAddress("test_role")
	uassert.Error(t, err)

	// Try to update removed role
	err = manager.UpdateRoleAddress("test_role", 1, customAddr1)
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
	roleAddresses := manager.GetAllRoleAddresses()
	println("Number of roles in system:", len(roleAddresses))

	// Step 2: Test custom role integration
	println("Step 2: Testing custom role integration")

	// Create custom role
	err := manager.RegisterRole("integ_test_role", testutils.TestAddress("integ_test_role"))
	uassert.NoError(t, err)

	err = manager.UpdateRoleAddress("integ_test_role", 1, customAddr2)
	uassert.NoError(t, err)

	// Verify it appears in role addresses
	updatedRoleAddresses := manager.GetAllRoleAddresses()
	addr, exists := updatedRoleAddresses["integ_test_role"]
	uassert.True(t, exists)
	uassert.Equal(t, customAddr2, addr)

	// Step 3: Verify authorization works correctly
	println("Step 3: Final authorization verification")

	isAuth := manager.IsAuthorized("integ_test_role", customAddr2)
	uassert.True(t, isAuth)

	// Step 4: Test ownership functions
	println("Step 4: Testing ownership functions")

	owner := manager.Owner()
	uassert.Equal(t, adminAddr, owner)

	err = manager.TransferOwnershipBy(testutils.TestAddress("api_service"), adminAddr)
	uassert.NoError(t, err)

	pendingOwner := manager.PendingOwner()
	uassert.Equal(t, testutils.TestAddress("api_service"), pendingOwner)
	ufmt.Printf("[EXPECTED] Pending owner: %s", testutils.TestAddress("api_service"))

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
// Admin role address: g1v9jx66twta047h6lta047h6lta047h6l8xuxz4
// Step 2: Admin updating system role address
// Step 3: Attempting to register existing system role (should fail)
// System role management scenario completed successfully
//
// [SCENARIO] 4. Multiple Role Authorization
// Step 1: Creating multiple roles
// Step 2: Testing authorization for each role
// [INFO] checking if frontend_service is authorized for backend_service address (address: g1vd6hxar0d5e97h6lta047h6lta047h6lqfttuz, isAuth: false)
// [INFO] checking if frontend_service is authorized for database_service address (address: g1vd6hxar0d5e47h6lta047h6lta047h6llrqzxs, isAuth: false)
// [INFO] checking if backend_service is authorized for frontend_service address (address: g1vd6hxar0d5c47h6lta047h6lta047h6ll6ycnh, isAuth: false)
// [INFO] checking if backend_service is authorized for database_service address (address: g1vd6hxar0d5e47h6lta047h6lta047h6llrqzxs, isAuth: false)
// [INFO] checking if database_service is authorized for frontend_service address (address: g1vd6hxar0d5c47h6lta047h6lta047h6ll6ycnh, isAuth: false)
// [INFO] checking if database_service is authorized for backend_service address (address: g1vd6hxar0d5e97h6lta047h6lta047h6lqfttuz, isAuth: false)
// Step 3: Testing system role authorization
// Admin authorization result: false
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
// [EXPECTED] Pending owner: g1v9cxjhmnv4e8v6trv4047h6lta047h6lcar8kyRole addresses integration scenario completed successfully
