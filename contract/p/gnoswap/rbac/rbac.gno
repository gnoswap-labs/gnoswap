package rbac

import (
	"errors"
	"strings"
)

// RBAC encapsulates and manages roles and their permissions.
// It combines role management with two-step ownership transfer functionality.
type RBAC struct {
	ownable *Ownable2Step
	// roles maps role names to their respective `Role` objects
	roles map[string]*Role
}

// NewRBACWithAddress creates a new RBAC instance with addr as owner.
//
// Parameters:
//   - addr: Address stored as the initial owner of the RBAC instance.
//
// Returns:
//   - *RBAC: New RBAC manager with an empty role registry and addr as owner.
func NewRBACWithAddress(addr address) *RBAC {
	return &RBAC{
		ownable: newOwnable2StepWithAddress(addr),
		roles:   make(map[string]*Role),
	}
}

// IsAuthorized checks if addr has the specified roleName. Returns false if the role does not exist.
//
// Parameters:
//   - roleName: Exact role name to look up in the role registry.
//   - addr: Address to compare with the address assigned to roleName.
//
// Returns:
//   - bool: true when roleName exists and its assigned address equals addr; false when it does not.
func (rb *RBAC) IsAuthorized(roleName string, addr address) bool {
	role, exists := rb.roles[roleName]
	if !exists {
		return false
	}

	return role.IsAuthorized(addr)
}

// RegisterRole registers a new role with given role name and address.
//
// Parameters:
//   - roleName: Role identifier; leading and trailing whitespace is removed before validation and storage.
//   - addr: Address initially assigned to the role; this method stores it without address validation.
//
// Errors:
// `RegisterRole` returns an error in the following situations:
//   - `ErrInvalidRoleName`: role name is an empty string or contains only whitespace
//   - `ErrRoleAlreadyExists`: the role to be registered already exists in RBAC.
//   - A system-role name may be registered when absent, but remains protected
//     from removal; this package does not pre-register system roles.
//
// Returns:
//   - error: nil when the trimmed role is registered; otherwise ErrInvalidRoleName or ErrRoleAlreadyExists.
func (rb *RBAC) RegisterRole(roleName string, addr address) error {
	roleName = strings.TrimSpace(roleName)
	if roleName == "" {
		return errors.New(ErrInvalidRoleName)
	}

	if rb.existsRole(roleName) {
		return errors.New(ErrRoleAlreadyExists)
	}

	rb.roles[roleName] = NewRole(roleName, addr)

	return nil
}

// UpdateRoleAddress assigns addr to roleName.
//
// Parameters:
//   - roleName: Existing role identifier; leading and trailing whitespace is removed before lookup.
//   - addr: Non-zero, syntactically valid address to assign to the role.
//
// Errors:
//   - `ErrInvalidRoleName`: role name is an empty string or contains only whitespace
//   - `ErrRoleDoesNotExist`: the specified role does not exist in the RBAC system
//   - `ErrInvalidAddress`: addr is empty or has an invalid format
//
// Returns:
//   - error: nil when the existing role is updated; otherwise an error identifying invalid input or a missing role.
func (rb *RBAC) UpdateRoleAddress(roleName string, addr address) error {
	roleName = strings.TrimSpace(roleName)
	if roleName == "" {
		return errors.New(ErrInvalidRoleName)
	}

	role, exists := rb.roles[roleName]
	if !exists {
		return errors.New(ErrRoleDoesNotExist)
	}

	if addr == zeroAddress || !addr.IsValid() {
		return errors.New(ErrInvalidAddress)
	}

	role.setAddress(addr)

	return nil
}

// RemoveRole removes roleName from the RBAC system.
//
// Parameters:
//   - roleName: Role identifier to remove; leading and trailing whitespace is removed before lookup.
//
// Errors:
//   - `ErrInvalidRoleName`: role name is an empty string or contains only whitespace
//   - `ErrRoleDoesNotExist`: the specified role does not exist in the RBAC system
//   - `ErrCannotRemoveSystemRole`: attempting to remove a system role (e.g., admin, governance, pool, etc.)
//
// Returns:
//   - error: nil when a non-system role is removed; otherwise an error for invalid, missing, or protected roles.
func (rb *RBAC) RemoveRole(roleName string) error {
	roleName = strings.TrimSpace(roleName)
	if roleName == "" {
		return errors.New(ErrInvalidRoleName)
	}

	if !rb.existsRole(roleName) {
		return errors.New(ErrRoleDoesNotExist)
	}

	// Check if it's a system role
	if IsSystemRole(roleName) {
		return errors.New(ErrCannotRemoveSystemRole)
	}

	// Simply delete the role since permissions are no longer managed here
	delete(rb.roles, roleName)

	return nil
}

// GetAllRoleAddresses returns a map of all role names to their assigned addresses.
//
// Returns:
//   - map[string]address: Newly allocated map containing each registered role name and its assigned address.
func (rb *RBAC) GetAllRoleAddresses() map[string]address {
	addresses := make(map[string]address)

	for roleName, role := range rb.roles {
		addresses[roleName] = role.Address()
	}

	return addresses
}

// GetRoleAddress returns the address assigned to roleName.
//
// Parameters:
//   - roleName: Exact role name to look up; this method does not trim whitespace.
//
// Errors:
//   - `ErrRoleDoesNotExist`: the specified role does not exist in the RBAC system
//
// Returns:
//   - address: Address assigned to roleName, or the empty address when the role is absent.
//   - error: nil when roleName exists; otherwise ErrRoleDoesNotExist.
func (rb *RBAC) GetRoleAddress(roleName string) (address, error) {
	role, exists := rb.roles[roleName]
	if !exists {
		return "", errors.New(ErrRoleDoesNotExist)
	}

	return role.Address(), nil
}

// Owner returns the current owner address.
//
// Returns:
//   - address: Current RBAC owner address, or the empty address if ownership has been dropped.
func (rb *RBAC) Owner() address {
	return rb.ownable.Owner()
}

// PendingOwner returns the pending owner address during ownership transfer.
//
// Returns:
//   - address: Pending owner address, or the empty address when no transfer is pending.
func (rb *RBAC) PendingOwner() address {
	return rb.ownable.PendingOwner()
}

// AcceptOwnershipBy completes the ownership transfer process.
// Must be called by the pending owner.
//
// Parameters:
//   - addr: Address attempting to accept ownership; it must equal the recorded pending owner.
//
// Errors:
//   - `ErrNoPendingOwner`: no ownership transfer is pending
//   - `ErrPendingUnauthorized`: addr is not the pending owner
//
// Returns:
//   - error: nil when ownership is transferred to addr; otherwise ErrNoPendingOwner or ErrPendingUnauthorized.
func (rb *RBAC) AcceptOwnershipBy(addr address) error {
	return rb.ownable.AcceptOwnershipBy(addr)
}

// DropOwnershipBy removes the owner, effectively disabling owner-only actions.
// This is irreversible and will prevent any future owner-only operations.
//
// Parameters:
//   - addr: Address requesting the drop; it must equal the current owner.
//
// Errors:
//   - `ErrUnauthorized`: addr is not the current owner
//
// Returns:
//   - error: nil when owner and pending owner are cleared; otherwise ErrUnauthorized.
func (rb *RBAC) DropOwnershipBy(addr address) error {
	return rb.ownable.DropOwnershipBy(addr)
}

// TransferOwnershipBy initiates the two-step ownership transfer process.
// The newOwner must call AcceptOwnershipBy to complete the transfer.
//
// Parameters:
//   - newOwner: Non-zero, syntactically valid address to record as the pending owner.
//   - caller: Address authorized to initiate the transfer; it must equal the current owner.
//
// Errors:
//   - `ErrUnauthorized`: caller is not the current owner
//   - `ErrInvalidAddress`: newOwner is empty or has an invalid format
//
// Returns:
//   - error: nil when the pending owner is set; otherwise ErrUnauthorized or ErrInvalidAddress.
func (rb *RBAC) TransferOwnershipBy(newOwner, caller address) error {
	return rb.ownable.TransferOwnershipBy(newOwner, caller)
}

// existsRole checks if name exists in the RBAC system.
//
// Parameters:
//   - name: Exact role name to test in the role registry.
//
// Returns:
//   - bool: true when name is a registered role key; false otherwise.
func (rb *RBAC) existsRole(name string) bool {
	_, exists := rb.roles[name]
	return exists
}
