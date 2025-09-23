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

// GetRoleAddresses returns a copy of all role addresses.
func GetRoleAddresses() map[string]std.Address {
	addresses := make(map[string]std.Address)

	for role, addr := range roleAddresses {
		addresses[role] = addr
	}

	return addresses
}

// Initialize sets up initial role addresses.
// Can only be called once during system initialization.
//
// Parameters:
//   - initialRoles: map of role names to addresses
//
// Only callable by RBAC contract.
func Initialize(cur realm, initialRoles map[string]std.Address) {
	caller := std.PreviousRealm().Address()
	assertIsRBAC(caller)

	// Skip if already initialized
	if len(roleAddresses) > 0 {
		return
	}

	// Validate all addresses before initialization
	for role, addr := range initialRoles {
		if !addr.IsValid() || addr == std.Address("") {
			panic(ufmt.Errorf("invalid address for role %s: %s", role, addr))
		}
	}

	// Verify required system roles are present
	requiredRoles := []string{
		"admin", "governance", "pool", "router", "position",
		"staker", "emission", "protocol_fee",
	}
	for _, role := range requiredRoles {
		if _, exists := initialRoles[role]; !exists {
			panic(ufmt.Errorf("missing required role: %s", role))
		}
	}

	roleAddresses = initialRoles
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
