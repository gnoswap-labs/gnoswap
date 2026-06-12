package referral

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	ErrInvalidAddress  = "invalid address format"
	ErrSelfReferral    = "self referral is not allowed"
	ErrUnauthorized    = "unauthorized caller"
	ErrTooManyRequests = "too many requests: operations allowed once per 24 hours for each address"
	ErrNotFound        = "referral not found"
	ErrInvalidTime     = "invalid time format"
)

func makeErrorWithDetails(message string, detail string) error {
	return ufmt.Errorf("%s: %s", message, detail)
}
