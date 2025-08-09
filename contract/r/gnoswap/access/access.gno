package access

import (
	"std"

	"gno.land/p/demo/ufmt"
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

// SetRoleAddresses updates all role addresses with the provided mapping.
// Validates all addresses before applying any updates. Panics if any address
// is invalid or if caller is not the RBAC contract.
// Only callable by RBAC contract.
func SetRoleAddresses(cur realm, newRoleAddresses map[string]std.Address) {
	caller := std.PreviousRealm().Address()
	assertIsRBAC(caller)

	// Validate all addresses before applying updates
	for role, addr := range newRoleAddresses {
		if !addr.IsValid() || addr == std.Address("") {
			panic(ufmt.Errorf("invalid address for role %s: %s", role, addr))
		}
	}

	roleAddresses = newRoleAddresses
}

// IsAuthorized returns true if the caller address matches the address
// assigned to the specified role. Returns false if the role doesn't exist
// or the caller doesn't match.
func IsAuthorized(role string, caller std.Address) bool {
	roleAddr, ok := roleAddresses[role]
	if !ok {
		return false
	}

	return caller == roleAddr
}
