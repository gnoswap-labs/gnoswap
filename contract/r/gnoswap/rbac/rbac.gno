package rbac

import (
	"std"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/p/demo/ufmt"
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

	for role, addr := range DefaultRoleAddresses {
		manager.RegisterRole(role.String())
		manager.UpdateRoleAddress(role.String(), addr)
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// Registers a new role in the RBAC system
// Only admin can register new roles
// System roles cannot be registered through this function
func RegisterRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	// validate input
	assertIsValidRoleName(roleName)

	err := manager.RegisterRole(roleName)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	// update access contract role addresses
	updateAccessRoleAddresses(manager.GetRoleAddresses())

	// emit register role event
	emitRegisterRoleEvent(roleName)
}

// Removes an existing role from the RBAC system
// Only admin can remove roles
// System roles cannot be removed through this function
func RemoveRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	// validate input
	assertIsValidRoleName(roleName)

	// remove role
	err := manager.RemoveRole(roleName)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	// update access contract role addresses
	updateAccessRoleAddresses(manager.GetRoleAddresses())

	// emit remove role event
	emitRemoveRoleEvent(roleName)
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
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
		))
	}

	// update access contract role addresses
	updateAccessRoleAddresses(manager.GetRoleAddresses())

	// emit update role address event
	emitUpdateRoleAddressEvent(roleName, addr)
}

// updateAccessRoleAddresses updates the role addresses in the access package
// by copying the default role addresses from RBAC system.
// This ensures that access package has the latest role-address mappings.
func updateAccessRoleAddresses(newRoleAddresses map[string]std.Address) {
	access.SetRoleAddresses(cross, newRoleAddresses)
}
