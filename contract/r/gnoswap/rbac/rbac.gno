package rbac

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/access"

	prbac "gno.land/p/gnoswap/rbac"
)

var manager *prbac.RBAC

func init() {
	initRbac()
}

// Initialize RBAC manager with default admin and roles
// Registers default system roles with predefined addresses
// Sets up initial role-based access control configuration
func initRbac() {
	manager = prbac.NewRBACWithAddress(ADMIN)

	for role := range defaultRoleAddresses {
		manager.RegisterRole(role.String())
		manager.UpdateRoleAddress(role.String(), defaultRoleAddresses[role])
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// Registers a new role in the RBAC system
// Only admin can register new roles
// System roles cannot be registered through this function
func RegisterRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	if prbac.IsSystemRole(roleName) {
		panic(ufmt.Errorf("cannot register system role %s", roleName))
	}

	err := manager.RegisterRole(roleName)
	if err != nil {
		panic(err)
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// Removes an existing role from the RBAC system
// Only admin can remove roles
// System roles cannot be removed through this function
func RemoveRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	if prbac.IsSystemRole(roleName) {
		panic(ufmt.Errorf("cannot remove system role %s", roleName))
	}

	err := manager.RemoveRole(roleName)
	if err != nil {
		panic(err)
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// Retrieves the address associated with a given role
// Returns error if role does not exist
// Used to verify role assignments and permissions
func GetRoleAddress(roleName string) (std.Address, error) {
	return manager.GetRoleAddress(roleName)
}

// Updates the address associated with a role
// Only admin can update role addresses
// Panics if role update fails
func UpdateRoleAddress(cur realm, roleName string, addr std.Address) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	err := manager.UpdateRoleAddress(roleName, addr)
	if err != nil {
		panic(err)
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// updateAccessRoleAddresses updates the role addresses in the access package
// by copying the default role addresses from RBAC system.
// This ensures that access package has the latest role-address mappings.
func updateAccessRoleAddresses(newRoleAddresses map[string]std.Address) {
	access.SetRoleAddresses(cross, newRoleAddresses)
}
