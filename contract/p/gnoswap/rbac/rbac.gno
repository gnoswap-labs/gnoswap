package rbac

import (
	"chain/runtime"
	"strings"
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
		ownable: newOwnable2StepWithAddress(runtime.OriginCaller()),
		roles:   make(map[string]*Role),
	}
}

// NewRBACWithAddress creates a new RBAC instance with addr as owner.
func NewRBACWithAddress(addr address) *RBAC {
	return &RBAC{
		ownable: newOwnable2StepWithAddress(addr),
		roles:   make(map[string]*Role),
	}
}

// IsAuthorized checks if addr has the specified roleName. Returns false if the role does not exist.
func (rb *RBAC) IsAuthorized(roleName string, addr address) bool {
	role, exists := rb.roles[roleName]
	if !exists {
		return false
	}

	return role.IsAuthorized(addr)
}

// RegisterRole registers a new role with given role name and address.
//
// Errors:
// `RegisterRole` returns an error in the following situations:
//  - `ErrInvalidRoleName`: role name is an empty string or contains only whitespace
//  - `ErrRoleAlreadyExists`: the role to be registered already exists in rbac.
//    Since system roles are registered through `initRbac`, attempting to register
//    a new role with a system role name will return an `ErrRoleAlreadyExists` error.
func (rb *RBAC) RegisterRole(roleName string, addr address) error {
	if strings.TrimSpace(roleName) == "" {
		return ErrInvalidRoleName
	}

	if rb.existsRole(roleName) {
		return ErrRoleAlreadyExists
	}

	rb.roles[roleName] = NewRole(roleName, addr)

	return nil
}

// UpdateRoleAddress assigns addr to roleName.
//
// Errors:
//   - `ErrInvalidRoleName`: role name is an empty string or contains only whitespace
//   - `ErrRoleDoesNotExist`: the specified role does not exist in the RBAC system
//   - `ErrInvalidAddress`: addr is empty or has an invalid format
func (rb *RBAC) UpdateRoleAddress(roleName string, addr address) error {
	if strings.TrimSpace(roleName) == "" {
		return ErrInvalidRoleName
	}

	role, exists := rb.roles[roleName]
	if !exists {
		return ErrRoleDoesNotExist
	}

	if addr == zeroAddress || !addr.IsValid() {
		return ErrInvalidAddress
	}

	role.setAddress(addr)

	return nil
}

// RemoveRole removes roleName from the RBAC system.
//
// Errors:
//   - `ErrInvalidRoleName`: role name is an empty string or contains only whitespace
//   - `ErrRoleDoesNotExist`: the specified role does not exist in the RBAC system
//   - `ErrCannotRemoveSystemRole`: attempting to remove a system role (e.g., admin, governance, pool, etc.)
func (rb *RBAC) RemoveRole(roleName string) error {
	if strings.TrimSpace(roleName) == "" {
		return ErrInvalidRoleName
	}

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

// GetAllRoleAddresses returns a map of all role names to their assigned addresses.
func (rb *RBAC) GetAllRoleAddresses() map[string]address {
	addresses := make(map[string]address)

	for roleName, role := range rb.roles {
		addresses[roleName] = role.Address()
	}

	return addresses
}

// GetRoleAddress returns the address assigned to roleName.
//
// Errors:
//   - `ErrRoleDoesNotExist`: the specified role does not exist in the RBAC system
func (rb *RBAC) GetRoleAddress(roleName string) (address, error) {
	role, exists := rb.roles[roleName]
	if !exists {
		return "", ErrRoleDoesNotExist
	}

	return role.Address(), nil
}

// Owner returns the current owner address.
func (rb *RBAC) Owner() address {
    return rb.ownable.Owner()
}

// PendingOwner returns the pending owner address during ownership transfer.
func (rb *RBAC) PendingOwner() address {
    return rb.ownable.PendingOwner()
}

// AcceptOwnershipBy completes the ownership transfer process.
// Must be called by the pending owner.
//
// Errors:
//   - `ErrNoPendingOwner`: no ownership transfer is pending
//   - `ErrPendingUnauthorized`: addr is not the pending owner
func (rb *RBAC) AcceptOwnershipBy(addr address) error {
    return rb.ownable.AcceptOwnershipBy(addr)
}

// DropOwnershipBy removes the owner, effectively disabling owner-only actions.
// This is irreversible and will prevent any future owner-only operations.
//
// Errors:
//   - `ErrUnauthorized`: addr is not the current owner
func (rb *RBAC) DropOwnershipBy(addr address) error {
    return rb.ownable.DropOwnershipBy(addr)
}

// TransferOwnershipBy initiates the two-step ownership transfer process.
// The newOwner must call AcceptOwnershipBy to complete the transfer.
//
// Errors:
//   - `ErrUnauthorized`: caller is not the current owner
//   - `ErrInvalidAddress`: newOwner is empty or has an invalid format
func (rb *RBAC) TransferOwnershipBy(newOwner, caller address) error {
	return rb.ownable.TransferOwnershipBy(newOwner, caller)
}

// existsRole checks if name exists in the RBAC system.
func (rb *RBAC) existsRole(name string) bool {
	_, exists := rb.roles[name]
	return exists
}
