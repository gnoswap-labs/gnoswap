package uint256

import (
	"errors"
)

var (
	ErrMissingPrefix    = errors.New("hex string without 0x prefix")
	ErrEmptyNumber      = errors.New("hex string \"0x\"")
	ErrLeadingZero      = errors.New("hex number with leading zero digits")
	ErrBig256Range      = errors.New("hex number > 256 bits")
	ErrBadEncodedLength = errors.New("bad ssz encoded length")
)

type u256Error struct {
	fn    string // function name
	input string
	err   error
}

func (e *u256Error) Error() string {
	return e.fn + ": " + e.input + ": " + e.err.Error()
}

func (e *u256Error) Unwrap() error {
	return e.err
}

func errMissingPrefix(fn, input string) error {
	return &u256Error{fn: fn, input: input, err: ErrMissingPrefix}
}

func errEmptyNumber(fn, input string) error {
	return &u256Error{fn: fn, input: input, err: ErrEmptyNumber}
}

func errLeadingZero(fn, input string) error {
	return &u256Error{fn: fn, input: input, err: ErrLeadingZero}
}

func errBig256Range(fn, input string) error {
	return &u256Error{fn: fn, input: input, err: ErrBig256Range}
}
