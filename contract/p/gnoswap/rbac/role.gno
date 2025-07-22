package rbac

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// Role represents a role information structure.
type Role struct {
	// name represents the role's identifier
	name string
	addresses   map[std.Address]struct{}
}

// NewRole creates a new `Role` instance with given name.
func NewRole(roleName string) *Role {
	return &Role{
		name:        roleName,
		addresses:   make(map[std.Address]struct{}),
	}
}

func (r *Role) Name() string { return r.name }

// RoleOption is a function type for applying options during role creation.
type RoleOption func(r *Role)

// DeclareRole registers a role and its permissions declaratively using the Functional Option pattern.
// Returns an error if the role already exists.
func (rb *RBAC) DeclareRole(roleName string, opts ...RoleOption) error {
	if rb.hasRole(roleName) {
		return ufmt.Errorf("role %s already exists", roleName)
	}
	role := NewRole(roleName)
	for _, opt := range opts {
		opt(role)
	}
	rb.roles[roleName] = role
	return nil
}
