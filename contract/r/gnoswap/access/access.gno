package access

import (
	"std"

	"gno.land/p/nt/ufmt"
)

var roleAddresses map[string]std.Address

func init() {
	roleAddresses = make(map[string]std.Address)
}

// GetAddress returns the address for a role and whether it exists.
func GetAddress(role string) (std.Address, bool) {
	addr, ok := roleAddresses[role]

	return addr, ok
}

func MustGetAddress(role string) std.Address {
	addr, ok := GetAddress(role)
	if !ok {
		panic(ufmt.Errorf("role %s not found", role))
	}
	return addr
}

// GetRoleAddresses returns a copy of all role addresses.
func GetRoleAddresses() map[string]std.Address {
	addresses := make(map[string]std.Address)

	for role, addr := range roleAddresses {
		addresses[role] = addr
	}

	return addresses
}

// SetRoleAddress sets or updates a role's address.
// Creates the role if it doesn't exist, updates it if it does.
//
// Parameters:
//   - roleName: name of the role
//   - roleAddress: address for the role
//
// Only callable by RBAC contract.
func SetRoleAddress(cur realm, roleName string, roleAddress std.Address) {
	caller := std.PreviousRealm().Address()
	assertIsRBAC(caller)

	// Validate address
	if !roleAddress.IsValid() || roleAddress == std.Address("") {
		panic(ufmt.Errorf("invalid address for role %s: %s", roleName, roleAddress))
	}

	roleAddresses[roleName] = roleAddress
}

// RemoveRole removes a role from the system.
//
// Parameters:
//   - roleName: name of the role to remove
//
// Only callable by RBAC contract.
func RemoveRole(cur realm, roleName string) {
	caller := std.PreviousRealm().Address()
	assertIsRBAC(caller)

	// Check if role exists
	if _, exists := roleAddresses[roleName]; !exists {
		panic(ufmt.Errorf("role %s does not exist", roleName))
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
	roleAddr, ok := roleAddresses[role]
	if !ok {
		return false
	}

	return caller == roleAddr
}
