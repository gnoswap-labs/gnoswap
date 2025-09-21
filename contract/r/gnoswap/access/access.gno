package access

import (
	"std"
)

var roleAddresses map[string][]std.Address

func init() {
	roleAddresses = make(map[string][]std.Address)
}

// GetAddress returns the address for a role and whether it exists.
func GetAddress(role string) (std.Address, bool) {
	addresses, ok := roleAddresses[role]
	if !ok {
		return "", false
	}

	if len(addresses) == 0 {
		return "", false
	}

	return addresses[len(addresses)-1], true
}

// GetAddressWithVersion returns the address for a role and whether it exists.
func GetAddressWithVersion(role string, version int) (std.Address, bool) {
	addresses, ok := roleAddresses[role]
	if !ok {
		return "", false
	}

	if version < 0 || version > len(addresses) {
		return "", false
	}

	index := version - 1

	return addresses[index], true
}

// GetRoleAddresses returns a copy of all role addresses.
func GetRoleAddresses() map[string][]std.Address {
	addresses := make(map[string][]std.Address)

	for role, data := range roleAddresses {
		addresses[role] = append(addresses[role], data...)
	}

	return addresses
}

// SetRoleAddresses updates all role addresses.
//
// Parameters:
//   - newRoleAddresses: map of role names to addresses
//
// Only callable by RBAC contract.
func SetRoleAddresses(cur realm, roleName string, addresses []std.Address) {
	caller := std.PreviousRealm().Address()
	assertIsRBAC(caller)

	roleAddresses[roleName] = addresses
}

// RemoveRole removes all role addresses.
//
// Parameters:
//   - roleName: role name to remove
//
// Only callable by RBAC contract.
func RemoveRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsRBAC(caller)

	if _, ok := roleAddresses[roleName]; !ok {
		panic("role does not exist")
	}

	delete(roleAddresses, roleName)
}

// IsAuthorized checks if caller has the specified role.
//
// Parameters:
//   - role: role name to check
//   - caller: address to verify
//
// Returns true if authorized, false otherwise.
func IsAuthorized(role string, caller std.Address) bool {
	addresses, ok := roleAddresses[role]
	if !ok {
		return false
	}

	for _, addr := range addresses {
		if caller == addr {
			return true
		}
	}

	return false
}

// IsAuthorizedWithVersion checks if caller has the specified role and version.
//
// Parameters:
//   - role: role name to check
//   - version: version to check
//   - caller: address to verify
//
// Returns true if authorized, false otherwise.
func IsAuthorizedWithVersion(role string, version int, caller std.Address) bool {
	addresses, ok := roleAddresses[role]
	if !ok {
		return false
	}

	if version < 0 || version > len(addresses) {
		return false
	}

	index := version - 1

	return caller == addresses[index]
}
