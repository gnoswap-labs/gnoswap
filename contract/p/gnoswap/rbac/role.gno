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

// DeclareRole registers a role and its permissions declaratively using the Functional Option pattern.
// Returns an error if the role already exists.
func (rb *RBAC) DeclareRole(roleName string) error {
	if rb.hasRole(roleName) {
		return ufmt.Errorf("role %s already exists", roleName)
	}
	rb.roles[roleName] = NewRole(roleName)
	return nil
}
