package rbac

import (
	"std"
)

// RBAC encapsulates and manages toles and their permissions.
type RBAC struct {
	ownable *Ownable2Step
	// roles maps role names to their respective `Role` objects
	roles map[string]*Role
}

// New creates a new RBAC instance.
func New() *RBAC {
	return &RBAC{
		ownable: newOwnable2StepWithAddress(std.OriginCaller()),
		roles:   make(map[string]*Role),
	}
}

func NewRBACWithAddress(addr std.Address) *RBAC {
	return &RBAC{
		ownable: newOwnable2StepWithAddress(addr),
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
		return ErrRoleAlreadyExists
	}

	rb.roles[roleName] = NewRole(roleName)

	return nil
}

func (rb *RBAC) RemoveRole(roleName string) error {
	if !rb.existsRole(roleName) {
		return ErrRoleDoesNotExist
	}

	// Check if it's a system role
	if IsSystemRole(roleName) {
		return ErrCannotRemoveSystemRole
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
		return "", ErrRoleDoesNotExist
	}

	return role.Address(), nil
}

// UpdateRoleAddress assigns a role to an address
func (rb *RBAC) UpdateRoleAddress(roleName string, addr std.Address) error {
	role, exists := rb.roles[roleName]
	if !exists {
		return ErrRoleDoesNotExist
	}

	if !addr.IsValid() {
		return ErrInvalidAddress
	}

	role.setAddress(addr)

	return nil
}

// RemoveRoleAddress removes a role address
func (rb *RBAC) RemoveRoleAddress(roleName string) error {
	if !rb.ownable.OwnedByOriginCaller() {
		return ErrUnauthorized
	}

	role, exists := rb.roles[roleName]
	if !exists {
		return ErrRoleDoesNotExist
	}

	role.setAddress("")

	return nil
}

// Ownership management
func (rb *RBAC) Owner() std.Address { return rb.ownable.Owner() }

// OwnedByOriginCaller checks if the caller of the function is the Realm's owner
func (rb *RBAC) OwnedByOriginCaller() bool { return rb.ownable.OwnedByOriginCaller() }

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
