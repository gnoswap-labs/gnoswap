package rbac

import (
	"errors"
	"std"

	"gno.land/p/demo/ufmt"
	oo "gno.land/p/oxtekgrinder/ownable2step"
)

var ErrUnauthorized = errors.New("caller is not owner")

// RBAC encapsulates and manages toles and their permissions.
type RBAC struct {
	ownable *oo.Ownable2Step
	// roles maps role names to their respective `Role` objects
	roles map[string]*Role
}

// New creates a new RBAC instance.
func New() *RBAC {
	return &RBAC{
		ownable: oo.New(),
		roles:   make(map[string]*Role),
	}
}

func NewRBACWithAddress(addr std.Address) *RBAC {
	return &RBAC{
		ownable: oo.NewWithAddress(addr),
		roles:   make(map[string]*Role),
	}
}

// Role management
// IsAuthorized checks if an address has a specific role
func (rb *RBAC) IsAuthorized(roleName string, addr std.Address) bool {
	role, exists := rb.roles[roleName]
	if !exists {
		return false
	}

	return role.IsAuthorized(addr)
}

// RegisterRole registers a role with the given role name.
// Returns an error if the role already exists.
func (rb *RBAC) RegisterRole(roleName string) error {
	if rb.existsRole(roleName) {
		return ufmt.Errorf("role %s already exists", roleName)
	}

	rb.roles[roleName] = NewRole(roleName)

	return nil
}

func (rb *RBAC) RemoveRole(roleName string) error {
	if !rb.existsRole(roleName) {
		return ufmt.Errorf("role %s does not exist", roleName)
	}

	// Check if it's a system role
	if IsSystemRole(roleName) {
		return ufmt.Errorf("cannot remove system role %s", roleName)
	}

	// Simply delete the role since permissions are no longer managed here
	delete(rb.roles, roleName)

	return nil
}

// GetRoleAddresses returns all role addresses
func (rb *RBAC) GetRoleAddresses() map[string]std.Address {
	addresses := make(map[string]std.Address)

	for role := range rb.roles {
		addresses[role] = rb.roles[role].Address()
	}

	return addresses
}

// GetRoleAddress returns the address with a specific role
func (rb *RBAC) GetRoleAddress(roleName string) (std.Address, error) {
	role, exists := rb.roles[roleName]
	if !exists {
		return "", ufmt.Errorf("role %s does not exist", roleName)
	}

	return role.Address(), nil
}

// UpdateRoleAddress assigns a role to an address
func (rb *RBAC) UpdateRoleAddress(roleName string, addr std.Address) error {
	role, exists := rb.roles[roleName]
	if !exists {
		return ufmt.Errorf("role %s does not exist", roleName)
	}

	if !addr.IsValid() {
		return ufmt.Errorf("invalid address %s", addr.String())
	}

	role.setAddress(addr)

	return nil
}

// RemoveRoleAddress removes a role address
func (rb *RBAC) RemoveRoleAddress(roleName string) error {
	if !rb.ownable.OwnedByPrevious() {
		return ErrUnauthorized
	}

	role, exists := rb.roles[roleName]
	if !exists {
		return ufmt.Errorf("role %s does not exist", roleName)
	}

	role.setAddress("")

	return nil
}

// Ownership management
func (rb *RBAC) Owner() std.Address { return rb.ownable.Owner() }

func (rb *RBAC) OwnedByPrevious() bool { return rb.ownable.OwnedByPrevious() }

// PendingOwner returns the pending owner address
func (rb *RBAC) PendingOwner() std.Address { return rb.ownable.PendingOwner() }

// AcceptOwnership completes the ownership transfer process
func (rb *RBAC) AcceptOwnership() error { return rb.ownable.AcceptOwnership() }

// DropOwnership removes the owner, effectively disabling owner-only actions
func (rb *RBAC) DropOwnership() error { return rb.ownable.DropOwnership() }

// TransferOwnership initiates the two-step ownership transfer process
func (rb *RBAC) TransferOwnership(newOwner std.Address) error {
	return rb.ownable.TransferOwnership(newOwner)
}

func (rb *RBAC) existsRole(name string) bool {
	_, exists := rb.roles[name]
	return exists
}
