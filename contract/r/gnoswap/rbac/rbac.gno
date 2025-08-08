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

// initRbac initializes RBAC manager with default admin and roles.
func initRbac() {
	manager = prbac.NewRBACWithAddress(ADMIN)

	for role, addr := range DefaultRoleAddresses {
		manager.RegisterRole(role.String())
		manager.UpdateRoleAddress(role.String(), addr)
	}

	updateAccessRoleAddresses(manager.GetRoleAddresses())
}

// RegisterRole registers new role in RBAC system.
// Only callable by admin.
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

// RemoveRole removes role from RBAC system.
// Only callable by admin.
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

// GetRoleAddress returns address for role.
func GetRoleAddress(roleName string) (std.Address, error) {
	return manager.GetRoleAddress(roleName)
}

// UpdateRoleAddress updates address for role.
// Only callable by admin.
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

// updateAccessRoleAddresses syncs role addresses to access package.
func updateAccessRoleAddresses(newRoleAddresses map[string]std.Address) {
	access.SetRoleAddresses(cross, newRoleAddresses)
}
