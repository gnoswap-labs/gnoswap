package access

import (
	"std"
)

var roleAddresses map[string]std.Address

func init() {
	roleAddresses = make(map[string]std.Address)
}

// GetAddress retrieves the address associated with a given role
// Returns the address and a boolean indicating if the role exists
// Used to verify role assignments and permissions
func GetAddress(role string) (std.Address, bool) {
	addr, ok := roleAddresses[role]

	return addr, ok
}

// GetRoleAddresses retrieves all role addresses
// Returns a map of role names to their corresponding addresses
// Used to get a complete view of all role-address mappings
func GetRoleAddresses() map[string]std.Address {
	addresses := make(map[string]std.Address)
	
	for role, addr := range roleAddresses {
		addresses[role] = addr
	}

	return addresses
}

// SetRoleAddresses updates the role addresses
// Takes a map of role names to their corresponding addresses
// Used to set the role addresses in the access package
func SetRoleAddresses(newRoleAddresses map[string]std.Address) {
	roleAddresses = newRoleAddresses
}

// IsAuthorized checks if the given caller address has the specified role
// Returns true if the caller matches the role's authorized address
// Returns false if the role doesn't exist or addresses don't match
func IsAuthorized(role string, caller std.Address) bool {
	roleAddr, ok := roleAddresses[role]
	if !ok {
		return false
	}

	return caller == roleAddr
}