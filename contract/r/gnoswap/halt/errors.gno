package halt

import (
	"errors"

	"gno.land/p/nt/ufmt"
)

var (
	errHalted           = errors.New("halted")
	errInvalidOpType    = errors.New("invalid operation type")
	errInvalidHaltLevel = errors.New("invalid halt level")
)

// makeErrorWithDetails creates an error with additional details appended to the base error message.
func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s: %s", err.Error(), details)
}
