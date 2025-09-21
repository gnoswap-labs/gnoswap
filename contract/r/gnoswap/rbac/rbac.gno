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

	for role, addr := range DefaultRoleAddresses {
		roleName := role.String()

		manager.RegisterRole(roleName, addr)
		updateAccessRoleAddresses(roleName)
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

	err := manager.RegisterRole(roleName, roleAddress)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidRoleName,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}

	updateAccessRoleAddresses(roleName)
	emitRegisterRoleEvent(roleName, 1, roleAddress)
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

	access.RemoveRole(cross, roleName)
	emitRemoveRoleEvent(roleName)
}

// UpdateRoleAddressNextVersion updates the address assigned to a role.
func UpdateRoleAddressNextVersion(roleName string, addr std.Address) {
	err := manager.UpdateRoleAddressNextVersion(roleName, addr)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
		))
	}

	newVersion := manager.GetRoleLatestVersion(roleName)

	updateAccessRoleAddresses(roleName)
	emitUpdateRoleAddressEvent(roleName, newVersion, addr)
}

// GetRoleAddress returns the address assigned to roleName.
func GetRoleAddress(roleName string) (std.Address, error) {
	return manager.GetRoleAddress(roleName)
}

// GetRoleAddressWithVersion returns the address assigned to roleName.
func GetRoleAddressWithVersion(roleName string, version int) (std.Address, error) {
	return manager.GetRoleAddressWithVersion(roleName, version)
}

// UpdateRoleAddress updates the address assigned to a role.
//
// Parameters:
//   - roleName: name of the role
//   - addr: new address for the role
//
// Only callable by admin or governance.
func UpdateRoleAddress(cur realm, roleName string, version int, addr std.Address) {
	caller := std.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	err := manager.UpdateRoleAddress(roleName, version, addr)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
		))
	}

	updateAccessRoleAddresses(roleName)
	emitUpdateRoleAddressEvent(roleName, version, addr)
}

// updateAccessRoleAddresses synchronizes role addresses with the access package.
func updateAccessRoleAddresses(roleName string) {
	addresses := manager.GetRoleAddresses(roleName)

	access.SetRoleAddresses(cross, roleName, addresses)
}
