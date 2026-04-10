package halt

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
)

var (
	errHalted             = errors.New("halted")
	errInvalidOpType      = errors.New("invalid operation type")
	errInvalidAction      = errors.New("invalid action")
	errInvalidHaltLevel   = errors.New("invalid halt level")
	errActionNotAllowed   = errors.New("action not allowed for domain")
	errPolicyNotFound     = errors.New("policy not found in config")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s: %s", err.Error(), details)
}
