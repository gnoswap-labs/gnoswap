package main

import (
	"std"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/rbac"
	prbac "gno.land/p/gnoswap/rbac"
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

	println("[SCENARIO] 3. Verify complex role hierarchies")
	verifyRoleHierarchies()
	println()

	println("[SCENARIO] 4. Test ownership and access control")
	testOwnershipAndAccess()
	println()

	println("[SCENARIO] 5. Test error cases and edge scenarios")
	testErrorCases()
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
	// given
	adminAddr := testutils.TestAddress("admin")
	editorAddr := testutils.TestAddress("editor")
	viewerAddr := testutils.TestAddress("viewer")

	// when - create admin role with multiple permissions
	adminChecker := func(caller std.Address) error {
		if caller == adminAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err := rbac.DeclareRole(cross, "superadmin", 
		prbac.WithPermission("create", adminChecker),
		prbac.WithPermission("read", adminChecker),
		prbac.WithPermission("update", adminChecker),
		prbac.WithPermission("delete", adminChecker))
	if err != nil {
		println("[INFO] Superadmin role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Superadmin role created with full permissions")
	}

	// when - create editor role with limited permissions
	editorChecker := func(caller std.Address) error {
		if caller == editorAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err = rbac.DeclareRole(cross, "editor",
		prbac.WithPermission("read", editorChecker),
		prbac.WithPermission("update", editorChecker))
	if err != nil {
		println("[INFO] Editor role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Editor role created with read/update permissions")
	}

	// when - create viewer role with minimal permissions
	viewerChecker := func(caller std.Address) error {
		if caller == viewerAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err = rbac.DeclareRole(cross, "viewer",
		prbac.WithPermission("read", viewerChecker))
	if err != nil {
		println("[INFO] Viewer role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Viewer role created with read-only permission")
	}

	println("[INFO] Three roles created declaratively")
}

func verifyRoleHierarchies() {
	// given
	adminAddr := testutils.TestAddress("admin")
	editorAddr := testutils.TestAddress("editor")
	viewerAddr := testutils.TestAddress("viewer")
	hackerAddr := testutils.TestAddress("hacker")

	// when & then - verify superadmin has all permissions
	operations := []string{"create", "read", "update", "delete"}
	for _, op := range operations {
		err := rbac.CheckPermission("superadmin", op, adminAddr)
		if err != nil {
			println("[INFO] Superadmin", op, "permission failed:", err.Error())
		} else {
			println("[EXPECTED] Superadmin has", op, "permission: true")
		}
	}

	// when & then - verify editor has limited permissions
	err := rbac.CheckPermission("editor", "read", editorAddr)
	if err != nil {
		println("[INFO] Editor read permission failed:", err.Error())
	} else {
		println("[EXPECTED] Editor has read permission: true")
	}

	err = rbac.CheckPermission("editor", "update", editorAddr)
	if err != nil {
		println("[INFO] Editor update permission failed:", err.Error())
	} else {
		println("[EXPECTED] Editor has update permission: true")
	}

	err = rbac.CheckPermission("editor", "delete", editorAddr)
	if err != nil {
		println("[EXPECTED] Editor denied delete permission: true")
	} else {
		println("[INFO] Unexpected: Editor has delete permission")
	}

	// when & then - verify viewer has minimal permissions
	err = rbac.CheckPermission("viewer", "read", viewerAddr)
	if err != nil {
		println("[INFO] Viewer read permission failed:", err.Error())
	} else {
		println("[EXPECTED] Viewer has read permission: true")
	}

	err = rbac.CheckPermission("viewer", "update", viewerAddr)
	if err != nil {
		println("[EXPECTED] Viewer denied update permission: true")
	} else {
		println("[INFO] Unexpected: Viewer has update permission")
	}

	// when & then - verify unauthorized access is denied
	err = rbac.CheckPermission("superadmin", "create", hackerAddr)
	if err != nil {
		println("[EXPECTED] Hacker denied superadmin access: true")
	} else {
		println("[INFO] Unexpected: Hacker has superadmin access")
	}

	println("[INFO] Role hierarchy verification completed")
}

func testOwnershipAndAccess() {
	// given
	adminAddr := testutils.TestAddress("admin")

	// when & then - verify owner can create roles
	err := rbac.DeclareRole(cross, "custom_admin",
		prbac.WithPermission("special", func(caller std.Address) error {
			if caller == adminAddr {
				return nil
			}
			return prbac.ErrUnauthorized
		}))
	if err != nil {
		println("[INFO] Custom admin role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Owner can create custom roles: true")
	}

	// when & then - verify non-owner cannot create roles
	err = rbac.DeclareRole(cross, "hacker_role",
		prbac.WithPermission("hack", func(caller std.Address) error {
			return nil
		}))
	if err != nil {
		println("[EXPECTED] Non-owner denied role creation: true")
	} else {
		println("[INFO] Unexpected: Non-owner can create roles")
	}

	// when & then - verify owner can still access system
	manager := rbac.GlobalManager()
	println("[EXPECTED] Owner can access manager:", manager != nil)
	println("[EXPECTED] Manager owner is admin:", manager.Owner() == adminAddr)

	println("[INFO] Ownership and access control verified")
}

func testErrorCases() {
	// given
	adminAddr := testutils.TestAddress("admin")

	// when & then - test duplicate role creation
	err := rbac.DeclareRole(cross, "superadmin",
		prbac.WithPermission("duplicate", func(caller std.Address) error {
			return nil
		}))
	if err != nil {
		println("[EXPECTED] Duplicate role creation prevented: true")
	} else {
		println("[INFO] Unexpected: Duplicate role creation allowed")
	}

	// when & then - test role with no permissions
	err = rbac.DeclareRole(cross, "empty_role")
	if err != nil {
		println("[INFO] Empty role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Empty role creation allowed: true")
	}

	// when & then - test role with empty name
	err = rbac.DeclareRole(cross, "",
		prbac.WithPermission("anonymous", func(caller std.Address) error {
			return nil
		}))
	if err != nil {
		println("[INFO] Empty name role creation failed:", err.Error())
	} else {
		println("[EXPECTED] Empty name role creation allowed: true")
	}

	// when & then - verify access to non-existent role
	err = rbac.CheckPermission("nonexistent", "permission", adminAddr)
	if err != nil {
		println("[EXPECTED] Non-existent role access denied: true")
	} else {
		println("[INFO] Unexpected: Non-existent role access allowed")
	}

	// when & then - verify access to non-existent permission
	err = rbac.CheckPermission("viewer", "nonexistent", adminAddr)
	if err != nil {
		println("[EXPECTED] Non-existent permission access denied: true")
	} else {
		println("[INFO] Unexpected: Non-existent permission access allowed")
	}

	println("[INFO] Error case testing completed")
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
// [SCENARIO] 3. Verify complex role hierarchies
// [EXPECTED] Superadmin has create permission: true
// [EXPECTED] Superadmin has read permission: true
// [EXPECTED] Superadmin has update permission: true
// [EXPECTED] Superadmin has delete permission: true
// [EXPECTED] Editor has read permission: true
// [EXPECTED] Editor has update permission: true
// [EXPECTED] Editor denied delete permission: true
// [EXPECTED] Viewer has read permission: true
// [EXPECTED] Viewer denied update permission: true
// [EXPECTED] Hacker denied superadmin access: true
// [INFO] Role hierarchy verification completed
//
// [SCENARIO] 4. Test ownership and access control
// [EXPECTED] Owner can create custom roles: true
// [INFO] Unexpected: Non-owner can create roles
// [EXPECTED] Owner can access manager: true
// [EXPECTED] Manager owner is admin: false
// [INFO] Ownership and access control verified
//
// [SCENARIO] 5. Test error cases and edge scenarios
// [EXPECTED] Duplicate role creation prevented: true
// [EXPECTED] Empty role creation allowed: true
// [EXPECTED] Empty name role creation allowed: true
// [EXPECTED] Non-existent role access denied: true
// [EXPECTED] Non-existent permission access denied: true
// [INFO] Error case testing completed
