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

// SatisfyCond checks if the given condition is true.
func SatisfyCond(cond bool) error {
	if !cond {
		return ufmt.Errorf("condition not satisfied")
	}
	return nil
}
