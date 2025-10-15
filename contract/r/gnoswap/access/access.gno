package access

import (
	"chain/runtime"

	"gno.land/p/nt/ufmt"
)

var (
	roleAddresses     map[string]map[int]address
	roleLatestVersion map[string]int
)

func init() {
	roleAddresses = make(map[string]map[int]address)
	roleLatestVersion = make(map[string]int)
}

// SetRoleAddress sets or updates a role's address.
// Creates the role if it doesn't exist, updates it if it does.
//
// Parameters:
//   - roleName: name of the role
//   - version: version of the role
//   - roleAddress: address for the role
//
// Only callable by RBAC contract.
func SetRoleAddress(cur realm, roleName string, version int, roleAddress address) {
	caller := runtime.PreviousRealm().Address()
	assertIsRBAC(caller)

	// Validate address
	if !roleAddress.IsValid() || roleAddress == address("") {
		panic(ufmt.Errorf("invalid address for role %s: %s", roleName, roleAddress))
	}

	_, ok := roleAddresses[roleName]
	if !ok {
		roleAddresses[roleName] = make(map[int]address)
	}

	roleAddresses[roleName][version] = roleAddress

	currentVersion, ok := roleLatestVersion[roleName]
	if !ok || currentVersion < version {
		roleLatestVersion[roleName] = version
	}
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

	if _, ok := roleAddresses[roleName]; !ok {
		panic("role does not exist")
	}

	delete(roleAddresses, roleName)
	delete(roleLatestVersion, roleName)
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

// IsAuthorizedWithVersion checks if caller has the specified role and version.
//
// Parameters:
//   - role: role name to check
//   - version: version to check
//   - caller: address to verify
//
// Returns true if authorized, false otherwise.
func IsAuthorizedWithVersion(role string, version int, caller address) bool {
	addr, ok := GetAddressWithVersion(role, version)
	if !ok {
		return false
	}

	return caller == addr
}

// GetAddress returns the address for a role and whether it exists.
func GetAddress(role string) (address, bool) {
	addresses, ok := roleAddresses[role]
	if !ok {
		return "", false
	}

	// If the role is not found in roleLatestVersion, find the latest version from the addresses
	latestVersion, ok := roleLatestVersion[role]
	if !ok {
		for version := range addresses {
			if latestVersion < version {
				latestVersion = version
			}
		}
	}

	addr, ok := addresses[latestVersion]
	if !ok {
		return "", false
	}

	return addr, true
}

// GetAddressWithVersion returns the address for a role and whether it exists.
func GetAddressWithVersion(role string, version int) (address, bool) {
	addresses, ok := roleAddresses[role]
	if !ok {
		return "", false
	}

	addr, ok := addresses[version]
	if !ok {
		return "", false
	}

	return addr, true
}

// GetRoleAddresses returns a copy of all role addresses.
func GetRoleAddresses() map[string]map[int]address {
	addresses := make(map[string]map[int]address)

	for role, data := range roleAddresses {
		addresses[role] = data
	}

	return addresses
}

func MustGetAddress(role string) address {
	addr, ok := GetAddress(role)
	if !ok {
		panic(ufmt.Errorf("role %s not found", role))
	}

	return addr
}

func MustGetAddressWithVersion(role string, version int) address {
	addr, ok := GetAddressWithVersion(role, version)
	if !ok {
		panic(ufmt.Errorf("role %s version %d not found", role, version))
	}

	return addr
}
