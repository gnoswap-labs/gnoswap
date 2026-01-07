package access

import (
    "chain"
	"chain/runtime"
	"strings"

	"gno.land/p/nt/ufmt"
)

var roleAddresses map[string]address

func init() {
	roleAddresses = make(map[string]address)
}

// SetRoleAddress sets or updates a role's address.
// Creates the role if it doesn't exist, updates it if it does.
//
// Parameters:
//   - cur: current realm (required by interrealm spec; not used directly)
//   - roleName: name of the role
//   - roleAddress: address for the role
//
// Only callable by RBAC contract.
func SetRoleAddress(cur realm, roleName string, roleAddress address) {
	caller := runtime.PreviousRealm().Address()
	assertIsRBAC(caller)

	// capture old value for event
	oldAddr, _ := roleAddresses[strings.TrimSpace(roleName)]

	if err := setRoleAddress(roleName, roleAddress); err != nil {
		panic(err)
	}

	chain.Emit(
	    "SetRoleAddress",
		"prevAddr", caller.String(),
		"role", roleName,
		"prevRoleAddr", oldAddr.String(),
		"roleAddress", roleAddress.String(),
	)
}

// setRoleAddress is the internal implementation of SetRoleAddress.
// Separated for testability.
func setRoleAddress(roleName string, roleAddress address) error {
    roleName = strings.TrimSpace(roleName)
    if roleName == "" {
		panic("role name cannot be empty")
	}

	// Validate address
	if !roleAddress.IsValid() || roleAddress == address("") {
		return ufmt.Errorf(errInvalidAddress, roleName, roleAddress)
	}

	roleAddresses[roleName] = roleAddress
	return nil
}

// RemoveRole removes a role from the system.
//
// Parameters:
//   - roleName: name of the role to remove
//
// Only callable by RBAC contract.
func RemoveRole(cur realm, roleName string) {
	caller := runtime.PreviousRealm().Address()
	assertIsRBAC(caller)

	// Validate role name
	roleName = strings.TrimSpace(roleName)
	if roleName == "" {
		panic("role name cannot be empty")
	}

	if _, ok := roleAddresses[roleName]; !ok {
		panic(ufmt.Errorf("role %s does not exist", roleName))
	}

	delete(roleAddresses, roleName)

	chain.Emit(
		"RemoveRole",
		"prevAddr", caller.String(),
		"role", roleName,
	)
}

// IsAuthorized checks if caller has the specified role.
//
// Parameters:
//   - role: role name to check
//   - caller: address to verify
//
// Returns true if authorized, false otherwise.
func IsAuthorized(role string, caller address) bool {
	addr, ok := GetAddress(role)
	if !ok {
		return false
	}

	return caller == addr
}

// GetAddress returns the address for a role and whether it exists.
func GetAddress(role string) (address, bool) {
    role = strings.TrimSpace(role)
	addr, ok := roleAddresses[role]
	return addr, ok
}

// GetRoleAddresses returns a copy of all role addresses.
func GetRoleAddresses() map[string]address {
	addresses := make(map[string]address)

	for role, data := range roleAddresses {
		addresses[role] = data
	}

	return addresses
}

// MustGetAddress returns the address for a role or panics if it doesn't exist.
// Use this when the role is expected to exist and failure is critical.
func MustGetAddress(role string) address {
    role = strings.TrimSpace(role)
	addr, ok := GetAddress(role)
	if !ok {
		panic(ufmt.Errorf(errRoleNotFound, role))
	}

	return addr
}
