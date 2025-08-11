package rbac

import (
	"std"
)

// Role represents a role with a name and an assigned address.
type Role struct {
	// name represents the role's identifier
	name    string
	address string
}

// NewRole creates a new Role instance with roleName.
func NewRole(roleName string) *Role {
	return &Role{
		name:    roleName,
		address: "",
	}
}

// Name returns the role's name.
func (r *Role) Name() string { return r.name }

// Address returns the address assigned to this role. Returns empty address if no address is assigned.
func (r *Role) Address() std.Address { return std.Address(r.address) }

// IsEmpty returns true if no address is assigned to this role.
func (r *Role) IsEmpty() bool { return r.address == "" }

// IsAuthorized returns true if addr matches the role's assigned address.
func (r *Role) IsAuthorized(addr std.Address) bool { return r.address == addr.String() }

// setAddress assigns addr to this role.
func (r *Role) setAddress(addr std.Address) { r.address = addr.String() }
