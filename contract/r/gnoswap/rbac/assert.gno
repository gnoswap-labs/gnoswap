package rbac

import (
	"std"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

func assertIsOwner(addr std.Address) {
	if manager.Owner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

func assertIsPendingOwner(addr std.Address) {
	if manager.PendingOwner() != addr {
		panic(makeErrorWithDetails(
			errCallerIsNotPendingOwner,
			ufmt.Sprintf("caller: %s", addr.String()),
		))
	}
}

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

func assertIsValidRoleName(roleName string) {
	if roleName == "" {
		panic(makeErrorWithDetails(
			errInvalidRoleName,
			ufmt.Sprintf("role name: %s", roleName),
		))
	}
}
