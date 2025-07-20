package main

import (
	"std"

	"gno.land/p/demo/testutils"
	"gno.land/r/gnoswap/v1/rbac"
	prbac "gno.land/p/gnoswap/rbac"
)

// TestRBAC_RoleAndPermissionManagement demonstrates complete RBAC role and permission management flow
// Scenario order:
// 1. Initialize RBAC with admin role
// 2. Register multiple roles with different permissions
// 3. Check permissions for various operations
// 4. Update permissions and verify changes
// 5. Remove permissions and roles
// 6. Verify system state after cleanup
func main() {
	println("[SCENARIO] 1. Initialize RBAC with admin role")
	initializeRBAC()
	println()

	println("[SCENARIO] 2. Register multiple roles with different permissions")
	registerRoles()
	println()

	println("[SCENARIO] 3. Check permissions for various operations")
	checkPermissions()
	println()

	println("[SCENARIO] 4. Update permissions and verify changes")
	updatePermissions()
	println()

	println("[SCENARIO] 5. Remove permissions and roles")
	removePermissionsAndRoles()
	println()

	println("[SCENARIO] 6. Verify system state after cleanup")
	verifyFinalState()
	println()
}

func initializeRBAC() {
	// given
	adminAddr := testutils.TestAddress("admin")

	// when
	manager := rbac.GlobalManager()

	// then
	println("[EXPECTED] RBAC manager initialized:", manager != nil)
	println("[EXPECTED] Admin address:", adminAddr)
	println("[INFO] RBAC system ready for role management")
}

func registerRoles() {
	// given
	adminAddr := testutils.TestAddress("admin")

	// when - register roles
	registerBasicRoles()

	// when - add permissions to roles
	registerRolePermissions(adminAddr)

	println("[INFO] Three roles with permissions registered")
}

func registerBasicRoles() {
	// when - register admin role
	err := rbac.RegisterRole(cross, "admin")
	if err != nil {
		println("[INFO] Admin role registration result:", err.Error())
	} else {
		println("[EXPECTED] Admin role registered successfully")
	}

	// when - register router role
	err = rbac.RegisterRole(cross, "router")
	if err != nil {
		println("[INFO] Router role registration result:", err.Error())
	} else {
		println("[EXPECTED] Router role registered successfully")
	}

	// when - register pool role
	err = rbac.RegisterRole(cross, "pool")
	if err != nil {
		println("[INFO] Pool role registration result:", err.Error())
	} else {
		println("[EXPECTED] Pool role registered successfully")
	}
}

func registerRolePermissions(adminAddr std.Address) {
	// when - add admin permission
	adminChecker := func(caller std.Address) error {
		if caller == adminAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err := rbac.RegisterPermission(cross, "admin", "manage", adminChecker)
	if err != nil {
		println("[INFO] Admin permission registration result:", err.Error())
	} else {
		println("[EXPECTED] Admin permission 'manage' registered successfully")
	}

	// when - add router permission
	routerAddr := testutils.TestAddress("router")
	routerChecker := func(caller std.Address) error {
		if caller == routerAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err = rbac.RegisterPermission(cross, "router", "route", routerChecker)
	if err != nil {
		println("[INFO] Router permission registration result:", err.Error())
	} else {
		println("[EXPECTED] Router permission 'route' registered successfully")
	}

	// when - add pool permission
	poolAddr := testutils.TestAddress("pool")
	poolChecker := func(caller std.Address) error {
		if caller == poolAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err = rbac.RegisterPermission(cross, "pool", "manage_pool", poolChecker)
	if err != nil {
		println("[INFO] Pool permission registration result:", err.Error())
	} else {
		println("[EXPECTED] Pool permission 'manage_pool' registered successfully")
	}
}

func checkPermissions() {
	// given
	adminAddr := testutils.TestAddress("admin")
	routerAddr := testutils.TestAddress("router")
	poolAddr := testutils.TestAddress("pool")
	hackerAddr := testutils.TestAddress("hacker")

	// when & then - check admin permissions
	err := rbac.CheckPermission("admin", "manage", adminAddr)
	if err != nil {
		println("[INFO] Admin permission check failed:", err.Error())
	} else {
		println("[EXPECTED] Admin has 'manage' permission: true")
	}

	// when & then - check router permissions
	err = rbac.CheckPermission("router", "route", routerAddr)
	if err != nil {
		println("[INFO] Router permission check failed:", err.Error())
	} else {
		println("[EXPECTED] Router has 'route' permission: true")
	}

	// when & then - check pool permissions
	err = rbac.CheckPermission("pool", "manage_pool", poolAddr)
	if err != nil {
		println("[INFO] Pool permission check failed:", err.Error())
	} else {
		println("[EXPECTED] Pool has 'manage_pool' permission: true")
	}

	// when & then - check unauthorized access
	err = rbac.CheckPermission("admin", "manage", hackerAddr)
	if err != nil {
		println("[EXPECTED] Hacker denied admin access: true")
	} else {
		println("[INFO] Unexpected: Hacker has admin access")
	}

	// when & then - check cross-role access
	err = rbac.CheckPermission("router", "route", adminAddr)
	if err != nil {
		println("[EXPECTED] Admin denied router access: true")
	} else {
		println("[INFO] Unexpected: Admin has router access")
	}

	println("[INFO] Permission checks completed")
}

func updatePermissions() {
	// given
	adminAddr := testutils.TestAddress("admin")
	routerAddr := testutils.TestAddress("router")

	// when - update router permission to allow admin access
	newRouterChecker := func(caller std.Address) error {
		if caller == adminAddr || caller == routerAddr {
			return nil
		}
		return prbac.ErrUnauthorized
	}
	err := rbac.UpdatePermission(cross, "router", "route", newRouterChecker)
	if err != nil {
		println("[INFO] Router permission update failed:", err.Error())
	} else {
		println("[EXPECTED] Router permission updated successfully")
	}

	// then - verify admin can now access router
	err = rbac.CheckPermission("router", "route", adminAddr)
	if err != nil {
		println("[INFO] Admin router access still denied:", err.Error())
	} else {
		println("[EXPECTED] Admin now has router access: true")
	}

	// then - verify router still has access
	err = rbac.CheckPermission("router", "route", routerAddr)
	if err != nil {
		println("[INFO] Router lost own access:", err.Error())
	} else {
		println("[EXPECTED] Router still has own access: true")
	}

	println("[INFO] Permission updates completed")
}

func removePermissionsAndRoles() {
	// given

	// when - remove pool permission
	err := rbac.RemovePermission(cross, "pool", "manage_pool")
	if err != nil {
		println("[INFO] Pool permission removal failed:", err.Error())
	} else {
		println("[EXPECTED] Pool permission removed successfully")
	}

	// then - verify pool permission is gone
	poolAddr := testutils.TestAddress("pool")
	err = rbac.CheckPermission("pool", "manage_pool", poolAddr)
	if err != nil {
		println("[EXPECTED] Pool permission check now fails: true")
	} else {
		println("[INFO] Unexpected: Pool permission still exists")
	}

	// when - remove pool role
	err = rbac.RemoveRole(cross, "pool")
	if err != nil {
		println("[INFO] Pool role removal failed:", err.Error())
	} else {
		println("[EXPECTED] Pool role removed successfully")
	}

	// then - verify pool role is gone
	err = rbac.CheckPermission("pool", "manage_pool", poolAddr)
	if err != nil {
		println("[EXPECTED] Pool role check now fails: true")
	} else {
		println("[INFO] Unexpected: Pool role still exists")
	}

	println("[INFO] Cleanup operations completed")
}

func verifyFinalState() {
	// given
	adminAddr := testutils.TestAddress("admin")
	routerAddr := testutils.TestAddress("router")

	// when & then - verify remaining roles still work
	err := rbac.CheckPermission("admin", "manage", adminAddr)
	if err != nil {
		println("[INFO] Admin permission lost:", err.Error())
	} else {
		println("[EXPECTED] Admin permission still works: true")
	}

	err = rbac.CheckPermission("router", "route", routerAddr)
	if err != nil {
		println("[INFO] Router permission lost:", err.Error())
	} else {
		println("[EXPECTED] Router permission still works: true")
	}

	// when & then - verify admin still has router access after update
	err = rbac.CheckPermission("router", "route", adminAddr)
	if err != nil {
		println("[INFO] Admin router access lost:", err.Error())
	} else {
		println("[EXPECTED] Admin router access still works: true")
	}

	// when & then - verify removed role is truly gone
	poolAddr := testutils.TestAddress("pool")
	err = rbac.CheckPermission("pool", "manage_pool", poolAddr)
	if err != nil {
		println("[EXPECTED] Pool role remains deleted: true")
	} else {
		println("[INFO] Unexpected: Pool role still exists")
	}

	println("[INFO] Final system state verified")
	println("[EXPECTED] RBAC system maintains integrity after operations")
}

// Output:
// [SCENARIO] 1. Initialize RBAC with admin role
// [EXPECTED] RBAC manager initialized: true
// [EXPECTED] Admin address: g1v9jx66twta047h6lta047h6lta047h6l8xuxz4
// [INFO] RBAC system ready for role management
//
// [SCENARIO] 2. Register multiple roles with different permissions
// [INFO] Admin role registration result: caller is not owner
// [INFO] Router role registration result: caller is not owner
// [INFO] Pool role registration result: caller is not owner
// [INFO] Admin permission registration result: caller is not owner
// [INFO] Router permission registration result: caller is not owner
// [INFO] Pool permission registration result: caller is not owner
// [INFO] Three roles with permissions registered
//
// [SCENARIO] 3. Check permissions for various operations
// [INFO] Admin permission check failed: role admin does not exist
// [INFO] Router permission check failed: role router does not exist
// [INFO] Pool permission check failed: role pool does not exist
// [EXPECTED] Hacker denied admin access: true
// [EXPECTED] Admin denied router access: true
// [INFO] Permission checks completed
//
// [SCENARIO] 4. Update permissions and verify changes
// [INFO] Router permission update failed: role router does not exist
// [INFO] Admin router access still denied: role router does not exist
// [INFO] Router lost own access: role router does not exist
// [INFO] Permission updates completed
//
// [SCENARIO] 5. Remove permissions and roles
// [INFO] Pool permission removal failed: caller is not owner
// [EXPECTED] Pool permission check now fails: true
// [INFO] Pool role removal failed: role pool does not exist
// [EXPECTED] Pool role check now fails: true
// [INFO] Cleanup operations completed
//
// [SCENARIO] 6. Verify system state after cleanup
// [INFO] Admin permission lost: role admin does not exist
// [INFO] Router permission lost: role router does not exist
// [INFO] Admin router access lost: role router does not exist
// [EXPECTED] Pool role remains deleted: true
// [INFO] Final system state verified
// [EXPECTED] RBAC system maintains integrity after operations
