package halt

import (
	"errors"

	"gno.land/p/demo/ufmt"
)

var (
	errHalted = errors.New("halted")
	errInvalidOpType = errors.New("invalid operation type")
	errInvalidHaltLevel = errors.New("invalid halt level")
)

func makeErrorWithDetails(err error, details string) error {
	return ufmt.Errorf("%s: %s", err.Error(), details)
}