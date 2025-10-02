// Simple RBAC scenario test demonstrating basic usage patterns
// Tests common real-world scenarios for role management

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

var t *testing.T

var (
	// Simulate different service addresses
	apiServiceAddr      = testutils.TestAddress("api_service")
	databaseServiceAddr = testutils.TestAddress("database_service")
	frontendServiceAddr = testutils.TestAddress("frontend_service")
	authServiceAddr     = testutils.TestAddress("auth_service")
	loggingServiceAddr  = testutils.TestAddress("logging_service")

	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

	// Create a test manager
	testManager *prbac.RBAC
)

func main() {
	println("[SCENARIO] 1. Initialize RBAC for microservices")
	initializeRBACForMicroservices()
	println()

	println("[SCENARIO] 2. Service Role Authorization Check")
	testServiceRoleAuthorization()
	println()

	println("[SCENARIO] 3. Dynamic Role Address Updates")
	testDynamicRoleUpdates()
	println()

	println("[SCENARIO] 4. Service Decommissioning")
	testServiceDecommissioning()
	println()
}

// Scenario: Setting up RBAC for a microservices architecture
func initializeRBACForMicroservices() {
	testing.SetOriginCaller(adminAddr)

	// Initialize RBAC manager
	testManager = prbac.NewRBACWithAddress(adminAddr)

	// Step 1: Register essential microservice roles
	println("[INFO] registering microservice roles")

	serviceRoles := map[string]address{
		"api_gateway":      apiServiceAddr,
		"database_service": databaseServiceAddr,
		"frontend_service": frontendServiceAddr,
		"auth_service":     authServiceAddr,
		"logging_service":  loggingServiceAddr,
	}

	// Step 2: Assign addresses to critical services
	println("[INFO] assigning addresses to services")

	for role, addr := range serviceRoles {
		err := testManager.RegisterRole(role, addr)
		uassert.NoError(t, err)
		println("[INFO] registered role:", role)
	}

	println("[EXPECTED] microservices RBAC initialization completed")
}

// Scenario: Testing service authorization in real-world context
func testServiceRoleAuthorization() {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] verifying service access permissions")

	// Test 1: API Gateway should be authorized for its role
	isAuthorized := testManager.IsAuthorized("api_gateway", apiServiceAddr)
	uassert.True(t, isAuthorized)
	println("[INFO] API Gateway authorization:", isAuthorized)

	// Test 2: Database service should be authorized for its role
	isAuthorized = testManager.IsAuthorized("database_service", databaseServiceAddr)
	uassert.True(t, isAuthorized)
	println("[INFO] Database Service authorization:", isAuthorized)

	// Test 3: Services should NOT be authorized for other roles
	isAuthorized = testManager.IsAuthorized("database_service", apiServiceAddr)
	uassert.False(t, isAuthorized)
	println("[INFO] Cross-service authorization prevention:", !isAuthorized)

	// Test 4: Unknown addresses should not be authorized
	unknownAddr := testutils.TestAddress("unknown_service")
	isAuthorized = testManager.IsAuthorized("api_gateway", unknownAddr)
	uassert.False(t, isAuthorized)
	println("[INFO] Unknown address rejection:", !isAuthorized)

	println("[EXPECTED] service authorization checks completed successfully")
}

// Scenario: Updating service addresses (like during deployment)
func testDynamicRoleUpdates() {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] simulating service redeployment with new addresses")

	// Get current address
	currentAddr, err := testManager.GetRoleAddress("frontend_service")
	uassert.NoError(t, err)
	println("[INFO] current frontend service address:", currentAddr.String())

	// Simulate redeployment with new address
	newFrontendAddr := testutils.TestAddress("new_frontend_service")

	// Update to new address
	err = testManager.UpdateRoleAddress("frontend_service", 1, newFrontendAddr)
	uassert.NoError(t, err)

	// Verify old address is no longer authorized
	oldIsAuth := testManager.IsAuthorized("frontend_service", frontendServiceAddr)
	uassert.False(t, oldIsAuth)
	println("[INFO] old address deauthorized:", !oldIsAuth)

	// Verify new address is authorized
	newIsAuth := testManager.IsAuthorized("frontend_service", newFrontendAddr)
	uassert.True(t, newIsAuth)
	println("[INFO] new address authorized:", newIsAuth)

	// Update the global variable for consistency
	frontendServiceAddr = newFrontendAddr

	println("[EXPECTED] dynamic role update completed successfully")
}

// Scenario: Removing services that are no longer needed
func testServiceDecommissioning() {
	testing.SetOriginCaller(adminAddr)

	println("[INFO] decommissioning unused service")

	// Verify the service exists before removal
	addr, err := testManager.GetRoleAddress("logging_service")
	uassert.NoError(t, err)
	println("[INFO] logging service address before removal:", addr.String())

	// Remove the service role
	err = testManager.RemoveRole("logging_service")
	uassert.NoError(t, err)

	// Verify the role no longer exists
	_, err = testManager.GetRoleAddress("logging_service")
	uassert.Error(t, err)
	println("[INFO] service role successfully removed")

	// Verify authorization fails for removed role
	isAuth := testManager.IsAuthorized("logging_service", testutils.TestAddress("any_addr"))
	uassert.False(t, isAuth)
	println("[INFO] authorization denied for removed service:", !isAuth)

	// Step 2: Verify other services are unaffected
	println("[INFO] verifying other services remain operational")

	remainingServices := map[string]address{
		"api_gateway":      apiServiceAddr,
		"database_service": databaseServiceAddr,
		"frontend_service": frontendServiceAddr,
	}

	for roleName, roleAddr := range remainingServices {
		isAuth := testManager.IsAuthorized(roleName, roleAddr)
		uassert.True(t, isAuth)
		println("[INFO] service", roleName, "still operational:", isAuth)
	}

	println("[EXPECTED] service decommissioning completed successfully")
}

// Output:
// [SCENARIO] 1. Initialize RBAC for microservices
// [INFO] registering microservice roles
// [INFO] assigning addresses to services
// [INFO] registered role: api_gateway
// [INFO] registered role: database_service
// [INFO] registered role: frontend_service
// [INFO] registered role: auth_service
// [INFO] registered role: logging_service
// [EXPECTED] microservices RBAC initialization completed
//
// [SCENARIO] 2. Service Role Authorization Check
// [INFO] verifying service access permissions
// [INFO] API Gateway authorization: true
// [INFO] Database Service authorization: true
// [INFO] Cross-service authorization prevention: true
// [INFO] Unknown address rejection: true
// [EXPECTED] service authorization checks completed successfully
//
// [SCENARIO] 3. Dynamic Role Address Updates
// [INFO] simulating service redeployment with new addresses
// [INFO] current frontend service address: g1veex7mn5v4hxghmnv4e8v6trv4047h6lmf7tz5
// [INFO] old address deauthorized: true
// [INFO] new address authorized: true
// [EXPECTED] dynamic role update completed successfully
//
// [SCENARIO] 4. Service Decommissioning
// [INFO] decommissioning unused service
// [INFO] logging service address before removal: g1d3hkwemfden47um9wfmxjcm9ta047h6ly32d8n
// [INFO] service role successfully removed
// [INFO] authorization denied for removed service: true
// [INFO] verifying other services remain operational
// [INFO] service api_gateway still operational: true
// [INFO] service database_service still operational: true
// [INFO] service frontend_service still operational: true
// [EXPECTED] service decommissioning completed successfully
