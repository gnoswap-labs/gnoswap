package rbac

import (
	"std"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
)

func assertIsOwner(addr std.Address) {
	if manager.Owner() != addr {
		panic(ufmt.Errorf("caller is not owner"))
	}
}

func assertIsPendingOwner(addr std.Address) {
	if manager.PendingOwner() != addr {
		panic(ufmt.Errorf("caller is not pending owner"))
	}
}

func assertIsAdmin(addr std.Address) {
	if !manager.IsAuthorized(prbac.ROLE_ADMIN.String(), addr) {
		panic(ufmt.Errorf("caller is not admin"))
	}
}

func assertIsValidRoleName(roleName string) {
	if roleName == "" {
		panic(ufmt.Errorf("role name is empty"))
	}
}
