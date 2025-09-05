package rbac

import (
	"std"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

// assertIsOwner panics if addr is not the current owner.
func assertIsOwner(addr std.Address) {
	if manager.Owner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

// assertIsPendingOwner panics if addr is not the pending owner.
func assertIsPendingOwner(addr std.Address) {
	if manager.PendingOwner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotPendingOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

// assertIsAdmin panics if addr is not authorized for admin role.
func assertIsAdmin(addr std.Address) {
	if !manager.IsAuthorized(prbac.ROLE_ADMIN.String(), addr) {
		panic(
			makeErrorWithDetails(
				errCallerIsNotAdmin,
				ufmt.Sprintf("caller: %s", addr.String()),
			),
		)
	}
}

// assertIsValidRoleName panics if roleName is invalid (empty).
func assertIsValidRoleName(roleName string) {
	if roleName == "" {
		panic(makeErrorWithDetails(
			errInvalidRoleName,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}
}
