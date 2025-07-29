package rbac

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errCallerIsNotOwner        = errors.New("caller is not owner")
	errCallerIsNotAdmin        = errors.New("caller is not admin")
	errCallerIsNotPendingOwner = errors.New("caller is not pending owner")
	errInvalidAddress          = errors.New("invalid address")
	errInvalidRoleName         = errors.New("invalid role name")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s || %s", err.Error(), details)
}
