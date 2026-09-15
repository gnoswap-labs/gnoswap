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

// makeErrorWithDetails formats a base halt error together with operation-specific details.
//
// Parameters:
//   - message: base error message describing the halt failure.
//   - details: operation name or other context appended after the base message.
//
// Returns:
//   - error: formatted error whose message joins message and details with ": ".
func makeErrorWithDetails(message string, details string) error {
	return ufmt.Errorf("%s: %s", message, details)
}
