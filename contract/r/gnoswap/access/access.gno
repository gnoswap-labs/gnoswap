package access

import (
	"chain"
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"
)

var roleAddresses map[string]address

// init initializes the in-memory mapping from role names to role addresses.
func init() {
	roleAddresses = make(map[string]address)
}

// SetRoleAddress sets or updates a role's address.
// It trims surrounding whitespace from roleName, creates missing roles, and
// replaces the address for an existing role.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - roleName: role identifier; surrounding whitespace is ignored and an empty name panics
//   - roleAddress: non-empty, valid address to associate with roleName
//
// Only callable by the RBAC contract.
func SetRoleAddress(cur realm, roleName string, roleAddress address) {
	prev := cur.Previous()
	assertIsRBAC(prev.Address())

	// capture old value for event
	oldAddr, _ := roleAddresses[strings.TrimSpace(roleName)]

	if err := setRoleAddress(roleName, roleAddress); err != nil {
		panic(err)
	}

	chain.Emit(
		"SetRoleAddress",
		"prevAddr", prev.Address().String(),
		"role", roleName,
		"prevRoleAddr", oldAddr.String(),
		"roleAddress", roleAddress.String(),
	)
}

// setRoleAddress stores a role address for the internal SetRoleAddress path.
// It trims roleName and panics for an empty name.
//
// Parameters:
//   - roleName: role identifier to normalize and store
//   - roleAddress: non-empty, valid address to associate with the normalized roleName
//
// Returns:
//   - error: nil after storing the mapping; non-nil when roleAddress is invalid or empty
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

// RemoveRole removes a role from the system after trimming its name.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - roleName: role identifier to trim and remove; an empty or unknown name panics
//
// Only callable by the RBAC contract.
func RemoveRole(cur realm, roleName string) {
	prev := cur.Previous()
	assertIsRBAC(prev.Address())

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
		"prevAddr", prev.Address().String(),
		"role", roleName,
	)
}

// IsAuthorized reports whether caller is the address currently mapped to role.
//
// Parameters:
//   - role: role name to trim and look up
//   - caller: address to compare with the mapped role address
//
// Returns:
//   - authorized: true when role exists and caller matches its address; false when the role is absent or does not match
func IsAuthorized(role string, caller address) bool {
	addr, ok := GetAddress(role)
	if !ok {
		return false
	}

	return caller == addr
}

// GetAddress returns the address mapped to a role and whether that mapping exists.
//
// Parameters:
//   - role: role name to trim before lookup
//
// Returns:
//   - addr: mapped address, or the zero address when role is not present
//   - exists: true when role has a stored address; false otherwise
func GetAddress(role string) (address, bool) {
	role = strings.TrimSpace(role)
	addr, ok := roleAddresses[role]
	return addr, ok
}

// GetRoleAddresses returns an independent map copy of all stored role addresses.
//
// Returns:
//   - roleAddresses: map from normalized role names to their configured addresses
func GetRoleAddresses() map[string]address {
	addresses := make(map[string]address)

	for role, data := range roleAddresses {
		addresses[role] = data
	}

	return addresses
}

// MustGetAddress returns the address mapped to a role or panics if it is absent.
// Surrounding whitespace is ignored; an empty or unknown role is considered absent.
//
// Parameters:
//   - role: role name to trim and require in the role mapping
//
// Returns:
//   - addr: configured address for role
func MustGetAddress(role string) address {
	role = strings.TrimSpace(role)
	addr, ok := GetAddress(role)
	if !ok {
		panic(ufmt.Errorf(errRoleNotFound, role))
	}

	return addr
}
