package halt

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
)

var (
	errHalted           = errors.New("halted")
	errInvalidOpType    = errors.New("invalid operation type")
	errInvalidHaltLevel = errors.New("invalid halt level")
	errOpTypeNotFound   = errors.New("operation type not found in config")
)

// makeErrorWithDetails creates an error with additional details appended to the base error message.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s: %s", err.Error(), details)
}
