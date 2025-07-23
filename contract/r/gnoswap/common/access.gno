package common

import (
	"std"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
)

const (
	ErrNoPermission = "caller(%s) has no permission"
)

// AssertCaller checks if the caller is the given address.
func AssertCaller(caller, addr std.Address) error {
	if caller != addr {
		return ufmt.Errorf(ErrNoPermission, caller.String())
	}
	return nil
}

func SatisfyCond(cond bool) error {
	if !cond {
		return ufmt.Errorf("given condition is not satisfied the permission check")
	}
	return nil
}

// UserOnly checks if the caller is a user.
func UserOnly(prev std.Realm) error {
	if !prev.IsUser() {
		return ufmt.Errorf("caller(%s) is not a user", prev.PkgPath())
	}
	return nil
}

// IsAuthorized is a wrapper around access.IsAuthorized that provides
// a consistent interface for role-based authorization checks
func IsAuthorized(role prbac.SystemRole, caller std.Address) bool {
	return access.IsAuthorized(role.String(), caller)
}

// RequireAuthorized checks if the caller has the specified role and panics if not
func RequireAuthorized(role prbac.SystemRole, caller std.Address) {
	if !IsAuthorized(role, caller) {
		panic(ufmt.Errorf(ErrNoPermission, caller.String()))
	}
}
