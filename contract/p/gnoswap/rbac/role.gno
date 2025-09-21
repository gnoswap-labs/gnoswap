package rbac

import (
	"std"
)

// Role represents a role with a name and an assigned address.
type Role struct {
	// name represents the role's identifier
	name          string
	addresses     []string
	latestVersion int
}

// NewRole creates a new Role instance with roleName.
func NewRole(roleName string, addr std.Address) *Role {
	return &Role{
		name:          roleName,
		addresses:     []string{addr.String()},
		latestVersion: 1,
	}
}

// Name returns the role's name.
func (r *Role) Name() string { return r.name }

// Address returns the address assigned to this role. Returns empty address if no address is assigned.
func (r *Role) Address(version int) std.Address {
	index, exists := r.getIndex(version)
	if !exists {
		return std.Address("")
	}

	return std.Address(r.addresses[index])
}

func (r *Role) CurrentAddress() std.Address {
	index, exists := r.getIndex(r.latestVersion)
	if !exists {
		return std.Address("")
	}

	return std.Address(r.addresses[index])
}

// IsEmpty returns true if no address is assigned to this role.
func (r *Role) IsEmpty() bool { return r.CurrentAddress() == "" }

// IsAuthorized returns true if addr matches the role's assigned address.
func (r *Role) IsAuthorized(addr std.Address) bool {
	return r.CurrentAddress().String() == addr.String()
}

func (r *Role) hasVersion(version int) bool {
	if version < 1 || version > r.latestVersion {
		return false
	}

	return true
}

func (r *Role) getIndex(version int) (int, bool) {
	if r.hasVersion(version) {
		return version - 1, true
	}

	return 0, false
}

// setAddress assigns addr to this role.
func (r *Role) setAddress(version int, addr std.Address) error {
	index, exists := r.getIndex(version)
	if !exists {
		return ErrVersionDoesNotExist
	}

	r.addresses[index] = addr.String()

	return nil
}

func (r *Role) nextVersionAddress(addr std.Address) error {
	r.addresses = append(r.addresses, addr.String())
	r.latestVersion = len(r.addresses)

	return nil
}
