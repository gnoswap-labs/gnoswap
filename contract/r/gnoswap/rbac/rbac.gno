package rbac

import (
	"std"

	"gno.land/r/gnoswap/access"

	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
)

var manager *prbac.RBAC

func init() {
	initRbac()
}

// initRbac initializes RBAC manager with default admin and role mappings.
func initRbac() {
	manager = prbac.NewRBACWithAddress(ADMIN)

	for role, addr := range DefaultRoleAddresses {
		manager.RegisterRole(role.String())
		manager.UpdateRoleAddress(role.String(), addr)
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// RegisterRole registers roleName in the RBAC system.
// Only callable by admin. Panics if caller is not admin or roleName is invalid.
func RegisterRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	assertIsValidRoleName(roleName)

	err := manager.RegisterRole(roleName)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())

	emitRegisterRoleEvent(roleName)
}

// RemoveRole removes roleName from the RBAC system.
// Only callable by admin. Panics if caller is not admin or roleName is invalid.
func RemoveRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsAdmin(caller)

	assertIsValidRoleName(roleName)

	err := manager.RemoveRole(roleName)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())

	emitRemoveRoleEvent(roleName)
}

// GetRoleAddress returns the address assigned to roleName.
func GetRoleAddress(roleName string) (std.Address, error) {
	return manager.GetRoleAddress(roleName)
}

// UpdateRoleAddress updates the address assigned to roleName to addr.
// Only callable by admin. Panics if caller is not admin or update fails.
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

	updateAccessRoleAddresses(manager.GetRoleAddresses())

	emitUpdateRoleAddressEvent(roleName, addr)
}

// updateAccessRoleAddresses synchronizes role addresses with the access package.
func updateAccessRoleAddresses(newRoleAddresses map[string]std.Address) {
	access.SetRoleAddresses(cross, newRoleAddresses)
}
