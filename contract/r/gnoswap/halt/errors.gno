package halt

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	errHalted           = "halted"
	errInvalidOpType    = "invalid operation type"
	errInvalidHaltLevel = "invalid halt level"
	errOpTypeNotFound   = "operation type not found in config"
)

// makeErrorWithDetails creates an error with additional details appended to the base error message.
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s: %s", message, details)
}
