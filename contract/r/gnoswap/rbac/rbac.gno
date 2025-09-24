package rbac

import (
	"std"

	"gno.land/r/gnoswap/access"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"
)

var manager *prbac.RBAC

func init() {
	initRbac()
}

// initRbac initializes RBAC manager with default admin and role mappings.
func initRbac() {
	manager = prbac.NewRBACWithAddress(ADMIN)

	// Prepare initial roles for one-time initialization
	initialRoles := make(map[string]std.Address)
	for role, addr := range DefaultRoleAddresses {
		manager.RegisterRole(role.String())
		manager.UpdateRoleAddress(role.String(), addr)
		initialRoles[role.String()] = addr

		// Update access package with the role address
		access.SetRoleAddress(cross, role.String(), addr)
	}
}

// RegisterRole registers a new role in the RBAC system.
//
// Parameters:
//   - roleName: name of the role to register
//   - roleAddress: address to assign to the role
//
// Only callable by admin or governance.
func RegisterRole(cur realm, roleName string, roleAddress std.Address) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsValidRoleName(roleName)

	// Validate the role address
	if !roleAddress.IsValid() || roleAddress == std.Address("") {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf(
			"cannot register role %s with invalid address %s", roleName, roleAddress,
		)))
	}

	err := manager.RegisterRole(roleName)
	if err != nil {
		if err.Error() == "role already exists" {
			panic(ufmt.Sprintf("role %s already exists", roleName))
		}
		panic(makeErrorWithDetails(
			errInvalidRoleName,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	// Update the role address immediately after registration
	err = manager.UpdateRoleAddress(roleName, roleAddress)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("failed to set address for role %s: %s", roleName, roleAddress),
		))
	}

	// Set the role in access control
	access.SetRoleAddress(cross, roleName, roleAddress)
	emitRegisterRoleEvent(roleName, roleAddress)
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

	// Remove the role from access control
	access.RemoveRole(cross, roleName)
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

	// Set the role address in access control
	access.SetRoleAddress(cross, roleName, addr)
	emitUpdateRoleAddressEvent(roleName, addr)
}
