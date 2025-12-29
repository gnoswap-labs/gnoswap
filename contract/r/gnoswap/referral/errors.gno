package referral

import (
	"errors"
)

var (
	ErrInvalidAddress  = errors.New("invalid address format")
	ErrSelfReferral    = errors.New("self referral is not allowed")
	ErrUnauthorized    = errors.New("unauthorized caller")
	ErrTooManyRequests = errors.New("too many requests: operations allowed once per 24 hours for each address")
	ErrNotFound        = errors.New("referral not found")
)
