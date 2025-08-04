package common

import (
	"std"
)

// AssertCaller checks if the caller is the given address.
func AssertCaller(caller, addr std.Address) error {
	if caller != addr {
		return makeErrorWithDetails(errNoPermission, caller.String())
	}
	return nil
}

// SatisfyCond checks if the given condition is true.
func SatisfyCond(cond bool) error {
	if !cond {
		return makeErrorWithDetails(errConditionNotSatisfied, "condition not satisfied")
	}
	return nil
}
