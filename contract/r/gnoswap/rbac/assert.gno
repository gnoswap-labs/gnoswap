package rbac

import (
	"strings"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
)

// assertIsOwner panics if address is not the current owner.
//
// Parameters:
//   - addr: address that must equal the configured owner
func assertIsOwner(addr address) {
	if manager.Owner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

// assertIsPendingOwner panics if address is not the pending owner.
//
// Parameters:
//   - addr: address that must equal the configured pending owner
func assertIsPendingOwner(addr address) {
	if manager.PendingOwner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotPendingOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

// assertIsAdmin panics if address is not authorized for admin role.
//
// Parameters:
//   - addr: address that must be authorized for the admin role
func assertIsAdmin(addr address) {
	if !manager.IsAuthorized(prbac.ROLE_ADMIN.String(), addr) {
		panic(
			makeErrorWithDetails(
				errCallerIsNotAdmin,
				ufmt.Sprintf("caller: %s", addr.String()),
			),
		)
	}
}

// assertIsValidRoleName panics if roleName is invalid (empty or whitespace-only).
//
// Parameters:
//   - roleName: role name that must contain non-whitespace text
func assertIsValidRoleName(roleName string) {
	if strings.TrimSpace(roleName) == "" {
		panic(makeErrorWithDetails(
			errInvalidRoleName,
			ufmt.Sprintf("role name: %q", roleName),
		))
	}
}

func assertIsValidAddress(addr address) {
	if !addr.IsValid() {
		panic(makeErrorWithDetails(
			errInvalidAddress,
			ufmt.Sprintf("address: %s", addr.String()),
		))
	}
}

func assertNotAdminRole(roleName string) {
	if strings.TrimSpace(roleName) == prbac.ROLE_ADMIN.String() {
		panic(makeErrorWithDetails(
			errAdminRoleUpdateForbidden,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}
}

func assertIsAdminOrGovernance(addr address) {
	if manager.IsAuthorized(prbac.ROLE_ADMIN.String(), addr) || manager.IsAuthorized(prbac.ROLE_GOVERNANCE.String(), addr) {
		return
	}

	panic(makeErrorWithDetails(
		errCallerIsNotAdminOrGovernance,
		ufmt.Sprintf("caller: %s", addr.String()),
	))
}
