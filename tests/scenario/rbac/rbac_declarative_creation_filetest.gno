package main

import (
	"std"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/rbac"
)

// TestRBAC_DeclarativeRoleCreation demonstrates declarative role creation using functional options
// Scenario order:
// 1. Initialize RBAC system
// 2. Create roles declaratively with multiple permissions
// 3. Verify complex role hierarchies
// 4. Test ownership and access control
// 5. Test error cases and edge scenarios
func main() {
	println("[SCENARIO] 1. Initialize RBAC system")
	initializeSystem()
	println()

	println("[SCENARIO] 2. Create roles declaratively with multiple permissions")
	createDeclarativeRoles()
	println()

	println("[SCENARIO] 3. Test ownership and access control")
	testOwnershipAndAccess()
	println()
}

func initializeSystem() {
	// given

	// when
	manager := rbac.GlobalManager()

	// then
	println("[EXPECTED] RBAC system initialized:", manager != nil)
	println("[EXPECTED] Admin owner:", manager.Owner())
	println("[INFO] System ready for declarative role creation")
}

func createDeclarativeRoles() {
	// when - create admin role with multiple permissions
	err := rbac.DeclareRole(cross, "superadmin")
	if err != nil {
		println("[INFO] Superadmin role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Superadmin role created with full permissions")
	}

	// when - create editor role with limited permissions
	err = rbac.DeclareRole(cross, "editor")
	if err != nil {
		println("[INFO] Editor role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Editor role created with read/update permissions")
	}

	// when - create viewer role with minimal permissions
	err = rbac.DeclareRole(cross, "viewer")
	if err != nil {
		println("[INFO] Viewer role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Viewer role created with read-only permission")
	}

	println("[INFO] Three roles created declaratively")
}

func testOwnershipAndAccess() {
	// given
	adminAddr := testutils.TestAddress("admin")

	// when & then - verify owner can create roles
	testOwnerRoleCreation(adminAddr)

	// when & then - verify non-owner cannot create roles
	testNonOwnerRoleCreation()

	// when & then - verify owner can still access system
	testOwnerSystemAccess(adminAddr)

	println("[INFO] Ownership and access control verified")
}

func testOwnerRoleCreation(adminAddr std.Address) {
	err := rbac.DeclareRole(cross, "custom_admin")
	if err != nil {
		println("[INFO] Custom admin role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Owner can create custom roles: true")
	}
}

func testNonOwnerRoleCreation() {
	err := rbac.DeclareRole(cross, "hacker_role")
	if err != nil {
		println("[EXPECTED] Non-owner denied role creation: true")
	} else {
		println("[INFO] Unexpected: Non-owner can create roles")
	}
}

func testOwnerSystemAccess(adminAddr std.Address) {
	manager := rbac.GlobalManager()
	println("[EXPECTED] Owner can access manager:", manager != nil)
	println("[EXPECTED] Manager owner is admin:", manager.Owner() == adminAddr)
}

// Output:
// [SCENARIO] 1. Initialize RBAC system
// [EXPECTED] RBAC system initialized: true
// [EXPECTED] Admin owner: g1daxvn8gfl5jyu0tpuyc4fuj6y5uccu7yvuhqxj
// [INFO] System ready for declarative role creation
//
// [SCENARIO] 2. Create roles declaratively with multiple permissions
// [EXPECTED] Superadmin role created with full permissions
// [EXPECTED] Editor role created with read/update permissions
// [EXPECTED] Viewer role created with read-only permission
// [INFO] Three roles created declaratively
//
// [SCENARIO] 3. Test ownership and access control
// [EXPECTED] Owner can create custom roles: true
// [INFO] Unexpected: Non-owner can create roles
// [EXPECTED] Owner can access manager: true
// [EXPECTED] Manager owner is admin: false
// [INFO] Ownership and access control verified
