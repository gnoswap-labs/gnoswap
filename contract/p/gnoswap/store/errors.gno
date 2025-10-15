package store

import "errors"

var (
	// Authorization errors
	ErrAuthorizedCallerAlreadyRegistered = errors.New("authorized caller already registered")
	ErrAuthorizedCallerNotFound          = errors.New("authorized caller not found")

	// Data access errors
	ErrKeyNotFound            = errors.New("key not found")
	ErrWritePermissionDenied  = errors.New("write permission denied")
	ErrReadPermissionDenied   = errors.New("read permission denied")
	ErrUpdatePermissionDenied = errors.New("update permission denied")
)
