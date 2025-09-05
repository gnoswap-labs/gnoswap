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

// SetRoleAddresses updates all role addresses.
//
// Parameters:
//   - newRoleAddresses: map of role names to addresses
//
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
