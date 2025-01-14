package referral

import (
	"gno.land/p/demo/ufmt"
)

const (
	ErrNone = iota
	ErrInvalidAddress
	ErrZeroAddress
	ErrSelfReferral
	ErrUnauthorized
	ErrInvalidCaller
	ErrCyclicReference
	ErrNotFound
)

var errorMessages = map[int]string{
	ErrInvalidAddress: "invalid address format",
	ErrZeroAddress:    "zero address is not allowed",
	ErrSelfReferral:   "self referral is not allowed",
	ErrUnauthorized:   "unauthorized caller",
	ErrInvalidCaller:  "invalid caller",
	ErrCyclicReference: "cyclic reference is not allowed",
	ErrNotFound:       "referral not found",
}

type ReferralError struct {
	Code    int
	Message string
	Err     error
}

func (e *ReferralError) Error() string {
	// TODO: format error message to follow previous error message format
	if e.Err != nil {
		return ufmt.Sprintf("code: %d, message: %s, error: %v", e.Code, e.Message, e.Err)
	}
	return ufmt.Sprintf("code: %d, message: %s", e.Code, e.Message)
}

func (e *ReferralError) Unwrap() error {
	return e.Err
}

func NewError(code int, args ...interface{}) *ReferralError {
	msg := errorMessages[code]
	var err error

	if len(args) > 0 {
		if lastArg, ok := args[len(args)-1].(error); ok {
			err = lastArg
		}
	}

	return &ReferralError{
		Code:    code,
		Message: msg,
		Err:     err,
	}
}
