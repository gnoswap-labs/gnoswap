package common

import (
	"std"
	"gno.land/p/demo/ufmt"
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
