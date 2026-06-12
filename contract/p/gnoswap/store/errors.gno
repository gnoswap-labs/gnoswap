package store

const (
	// Authorization errors
	ErrAuthorizedCallerAlreadyRegistered = "authorized caller already registered"
	ErrAuthorizedCallerNotFound          = "authorized caller not found"
	ErrInvalidPermission                 = "invalid permission"

	// Data access errors
	ErrKeyNotFound            = "key not found"
	ErrWritePermissionDenied  = "write permission denied"
	ErrUpdatePermissionDenied = "update permission denied"
	ErrFailedCast             = "failed to cast"
	ErrSpoofedRealm           = "rlm does not match the current crossing frame"
)
