package rbac

import (
	"chain"

	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"
)

var manager *prbac.RBAC

func init(cur realm) {
	initRbac(cur)
}

// initRbac initializes RBAC manager with default admin and role mappings.
func initRbac(cur realm) {
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Prepare initial roles for one-time initialization
	for role, addr := range DefaultRoleAddresses {
		roleName := role.String()
		err := manager.RegisterRole(roleName, addr)
		if err != nil {
			panic(makeErrorWithDetails(
				err,
				ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
			))
		}

		// Update access package with the role address
		access.SetRoleAddress(cross(cur), roleName, addr)
	}
}

// RegisterRole registers a new role in the RBAC system.
//
// Parameters:
//   - roleName: name of the role to register
//   - roleAddress: address to assign to the role
//
// Only callable by admin or governance.
func RegisterRole(cur realm, roleName string, roleAddress address) {
	prev := cur.Previous()
	caller := prev.Address()
	assertIsAdminOrGovernance(caller)
	assertIsValidRoleName(roleName)
	assertIsValidAddress(roleAddress)

	err := manager.RegisterRole(roleName, roleAddress)
	if err != nil {
		if err.Error() == "role already exists" {
			panic(ufmt.Sprintf("role %s already exists", roleName))
		}
		panic(makeErrorWithDetails(
			errInvalidRoleName,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	// Set the role in access control
	access.SetRoleAddress(cross(cur), roleName, roleAddress)
	chain.Emit(
		"RegisterRole",
		"prevAddr", caller.String(),
		"prevRealm", prev.PkgPath(),
		"roleName", roleName,
		"roleAddress", roleAddress.String(),
	)
}

// UpdateRoleAddress updates the address assigned to a role.
//
// Parameters:
//   - roleName: name of the role
//   - addr: new address for the role
//
// Only callable by admin or governance.
func UpdateRoleAddress(cur realm, roleName string, addr address) {
	prev := cur.Previous()
	caller := prev.Address()
	assertIsAdminOrGovernance(caller)

	assertIsValidRoleName(roleName)
	assertIsValidAddress(addr)
	assertNotAdminRole(roleName)

	err := manager.UpdateRoleAddress(roleName, addr)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
		))
	}

	// Set the role address in access control
	access.SetRoleAddress(cross(cur), roleName, addr)

	chain.Emit(
		"UpdateRoleAddress",
		"prevAddr", caller.String(),
		"prevRealm", prev.PkgPath(),
		"roleName", roleName,
		"roleAddress", addr.String(),
	)
}

// RemoveRole removes a role from the RBAC system.
//
// Parameters:
//   - roleName: name of the role to remove
//
// Only callable by admin or governance.
func RemoveRole(cur realm, roleName string) {
	prev := cur.Previous()
	caller := prev.Address()
	assertIsAdminOrGovernance(caller)
	assertIsValidRoleName(roleName)
	assertNotAdminRole(roleName)

	err := manager.RemoveRole(roleName)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	// Remove the role from access control
	access.RemoveRole(cross(cur), roleName)
	chain.Emit(
		"RemoveRole",
		"prevAddr", caller.String(),
		"prevRealm", prev.PkgPath(),
		"roleName", roleName,
		"roleAddress", "",
	)
}

// GetRoleAddress returns the address assigned to roleName.
func GetRoleAddress(roleName string) (address, error) {
	return manager.GetRoleAddress(roleName)
}
