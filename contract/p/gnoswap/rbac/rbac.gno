package rbac

import (
	"std"
)

// RBAC encapsulates and manages roles and their permissions.
// It combines role management with two-step ownership transfer functionality.
type RBAC struct {
	ownable *Ownable2Step
	// roles maps role names to their respective `Role` objects
	roles map[string]*Role
}

// New creates a new RBAC instance with the origin caller as owner.
func New() *RBAC {
	return &RBAC{
		ownable: newOwnable2StepWithAddress(std.OriginCaller()),
		roles:   make(map[string]*Role),
	}
}

// NewRBACWithAddress creates a new RBAC instance with addr as owner.
func NewRBACWithAddress(addr std.Address) *RBAC {
	return &RBAC{
		ownable: newOwnable2StepWithAddress(addr),
		roles:   make(map[string]*Role),
	}
}

// IsAuthorized checks if addr has the specified roleName. Returns false if the role does not exist.
func (rb *RBAC) IsAuthorized(roleName string, addr std.Address) bool {
	role, exists := rb.roles[roleName]
	if !exists {
		return false
	}

	return role.IsAuthorized(addr)
}

// RegisterRole registers a new role with roleName. Returns ErrRoleAlreadyExists if the role already exists.
func (rb *RBAC) RegisterRole(roleName string) error {
	if rb.existsRole(roleName) {
		return ErrRoleAlreadyExists
	}

	rb.roles[roleName] = NewRole(roleName)

	return nil
}

// RemoveRole removes roleName from the RBAC system. Returns ErrRoleDoesNotExist if the role doesn't exist or ErrCannotRemoveSystemRole for system roles.
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

// GetRoleAddresses returns a map of all role names to their assigned addresses.
func (rb *RBAC) GetRoleAddresses() map[string]std.Address {
	addresses := make(map[string]std.Address)

	for role := range rb.roles {
		addresses[role] = rb.roles[role].Address()
	}

	return addresses
}

// GetRoleAddress returns the address assigned to roleName. Returns ErrRoleDoesNotExist if the role doesn't exist.
func (rb *RBAC) GetRoleAddress(roleName string) (std.Address, error) {
	role, exists := rb.roles[roleName]
	if !exists {
		return "", ErrRoleDoesNotExist
	}

	return role.Address(), nil
}

// UpdateRoleAddress assigns addr to roleName. Returns ErrRoleDoesNotExist if the role doesn't exist or ErrInvalidAddress if addr is invalid.
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

// RemoveRoleAddress removes the address assignment from roleName. Only the owner can call this function. Returns ErrUnauthorized if caller is not owner or ErrRoleDoesNotExist if role doesn't exist.
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

// Owner returns the current owner address.
func (rb *RBAC) Owner() std.Address { return rb.ownable.Owner() }

// OwnedByOriginCaller returns true if the origin caller is the current owner.
func (rb *RBAC) OwnedByOriginCaller() bool { return rb.ownable.OwnedByOriginCaller() }

// PendingOwner returns the pending owner address during ownership transfer.
func (rb *RBAC) PendingOwner() std.Address { return rb.ownable.PendingOwner() }

// AcceptOwnership completes the ownership transfer process. Must be called by the pending owner.
func (rb *RBAC) AcceptOwnership() error { return rb.ownable.AcceptOwnership() }

// DropOwnership removes the owner, effectively disabling owner-only actions. Only the current owner can call this function.
func (rb *RBAC) DropOwnership() error { return rb.ownable.DropOwnership() }

// TransferOwnership initiates the two-step ownership transfer process to newOwner. Only the current owner can call this function.
func (rb *RBAC) TransferOwnership(newOwner std.Address) error {
	return rb.ownable.TransferOwnership(newOwner)
}

// existsRole checks if name exists in the RBAC system.
func (rb *RBAC) existsRole(name string) bool {
	_, exists := rb.roles[name]
	return exists
}
