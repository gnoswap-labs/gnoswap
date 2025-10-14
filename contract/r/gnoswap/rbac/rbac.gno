package rbac

import (
	"chain/runtime"

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
	for role, addr := range DefaultRoleAddresses {
		err := manager.RegisterRole(role.String(), addr)
		if err != nil {
			panic(makeErrorWithDetails(
				err,
				ufmt.Sprintf("role name: %s, address: %s", role.String(), addr.String()),
			))
		}

		registeredVersion := manager.GetRoleLatestVersion(role.String())

		// Update access package with the role address
		access.SetRoleAddress(cross, role.String(), registeredVersion, addr)
	}
}

// RegisterRole registers a new role in the RBAC system.
// registered role version is 1 by initialization
//
// Parameters:
//   - roleName: name of the role to register
//   - roleAddress: address to assign to the role
//
// Only callable by admin or governance.
func RegisterRole(cur realm, roleName string, roleAddress address) {
	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)
	assertIsValidRoleName(roleName)

	// Validate the role address
	if !roleAddress.IsValid() || roleAddress == address("") {
		panic(makeErrorWithDetails(errInvalidAddress, ufmt.Sprintf(
			"cannot register role %s with invalid address %s", roleName, roleAddress,
		)))
	}

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

	registeredVersion := manager.GetRoleLatestVersion(roleName)

	// Update the role address immediately after registration
	err = manager.UpdateRoleAddress(roleName, registeredVersion, roleAddress)
	if err != nil {
		panic(makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("failed to set address for role %s: %s", roleName, roleAddress),
		))
	}

	// Set the role in access control
	access.SetRoleAddress(cross, roleName, registeredVersion, roleAddress)
	emitRegisterRoleEvent(roleName, registeredVersion, roleAddress)
}

// UpdateRoleAddress updates the address assigned to a role.
//
// Parameters:
//   - roleName: name of the role
//   - addr: new address for the role
//
// Only callable by admin or governance.
func UpdateRoleAddress(cur realm, roleName string, version int, addr address) {
	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)
	assertIsValidRoleName(roleName)

	err := manager.UpdateRoleAddress(roleName, version, addr)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
		))
	}

	// Set the role address in access control
	access.SetRoleAddress(cross, roleName, version, addr)
	emitUpdateRoleAddressEvent(roleName, version, addr)
}

// UpdateRoleAddressNextVersion updates the address assigned to a role new version.
// updated version is incremented by 1
//
// Parameters:
//   - roleName: name of the role
//   - addr: new address for the role
//
// Only callable by admin or governance.
func UpdateRoleAddressNextVersion(cur realm, roleName string, addr address) {
	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)
	assertIsValidRoleName(roleName)

	err := manager.UpdateRoleAddressNextVersion(roleName, addr)
	if err != nil {
		panic(makeErrorWithDetails(
			err,
			ufmt.Sprintf("role name: %s, address: %s", roleName, addr.String()),
		))
	}

	newVersion := manager.GetRoleLatestVersion(roleName)

	// Set the role address in access control
	access.SetRoleAddress(cross, roleName, newVersion, addr)
	emitUpdateRoleAddressEvent(roleName, newVersion, addr)
}

// RemoveRole removes a role from the RBAC system.
//
// Parameters:
//   - roleName: name of the role to remove
//
// Only callable by admin or governance.
func RemoveRole(cur realm, roleName string) {
	caller := runtime.PreviousRealm().Address()
	assertIsAdminOrGovernance(caller)
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
func GetRoleAddress(roleName string) (address, error) {
	return manager.GetRoleAddress(roleName)
}

// GetRoleAddressWithVersion returns the address assigned to roleName.
func GetRoleAddressWithVersion(roleName string, version int) (address, error) {
	return manager.GetRoleAddressWithVersion(roleName, version)
}
