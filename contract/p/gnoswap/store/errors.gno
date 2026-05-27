package store

import "errors"

var (
	// Authorization errors
	ErrAuthorizedCallerAlreadyRegistered = errors.New("authorized caller already registered")
	ErrAuthorizedCallerNotFound          = errors.New("authorized caller not found")
	ErrInvalidPermission                 = errors.New("invalid permission")

	// Data access errors
	ErrKeyNotFound            = errors.New("key not found")
	ErrWritePermissionDenied  = errors.New("write permission denied")
	ErrUpdatePermissionDenied = errors.New("update permission denied")
	ErrFailedCast             = errors.New("failed to cast")
	ErrSpoofedRealm           = errors.New("rlm does not match the current crossing frame")
)
