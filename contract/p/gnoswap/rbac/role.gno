package rbac

import (
	"std"
)

// Role represents a role information structure.
type Role struct {
	// name represents the role's identifier
	name    string
	address string
}

// NewRole creates a new `Role` instance with given name.
func NewRole(roleName string) *Role {
	return &Role{
		name:    roleName,
		address: "",
	}
}

func (r *Role) Name() string { return r.name }

func (r *Role) Address() std.Address { return std.Address(r.address) }

func (r *Role) IsEmpty() bool { return r.address == "" }

func (r *Role) IsAuthorized(addr std.Address) bool { return r.address == addr.String() }

func (r *Role) setAddress(addr std.Address) { r.address = addr.String() }
