package rbac

import (
	"strings"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

// assertIsOwner panics if address is not the current owner.
func assertIsOwner(addr address) {
	if manager.Owner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

// assertIsPendingOwner panics if address is not the pending owner.
func assertIsPendingOwner(addr address) {
	if manager.PendingOwner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotPendingOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

// assertIsAdmin panics if address is not authorized for admin role.
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
	if roleName == prbac.ROLE_ADMIN.String() {
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
