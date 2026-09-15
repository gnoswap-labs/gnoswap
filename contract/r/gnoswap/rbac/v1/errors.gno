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

// makeErrorWithDetails combines an error with additional details.
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s || %s", message, details)
}
