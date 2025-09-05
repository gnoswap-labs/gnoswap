package rbac

import (
	"std"

	"gno.land/r/gnoswap/access"

	"gno.land/p/nt/ufmt"
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

// RegisterRole registers a new role in the RBAC system.
//
// Parameters:
//   - roleName: name of the role to register
//
// Only callable by admin or governance.
func RegisterRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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

// RemoveRole removes a role from the RBAC system.
//
// Parameters:
//   - roleName: name of the role to remove
//
// Only callable by admin or governance.
func RemoveRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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

// UpdateRoleAddress updates the address assigned to a role.
//
// Parameters:
//   - roleName: name of the role
//   - addr: new address for the role
//
// Only callable by admin or governance.
func UpdateRoleAddress(cur realm, roleName string, addr std.Address) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

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
