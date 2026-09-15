package rbac

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errCallerIsNotOwner             = "caller is not owner"
	errCallerIsNotAdmin             = "caller is not admin"
	errCallerIsNotAdminOrGovernance = "caller is not admin or governance"
	errCallerIsNotPendingOwner      = "caller is not pending owner"
	errInvalidAddress               = "invalid address"
	errInvalidRoleName              = "invalid role name"
	errAdminRoleUpdateForbidden     = "admin role is managed by owner"
)

// makeErrorWithDetails formats an RBAC error together with contextual details.
//
// Parameters:
//   - message: base error message describing the authorization or role failure.
//   - details: role name, address, or other context appended to the message.
//
// Returns:
//   - error: formatted error containing message and details separated by " || ".
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
