package storage

import "errors"

var (
	ErrAuthorizedCallerAlreadyRegistered = errors.New("authorized caller already registered")
	ErrAuthorizedCallerNotFound          = errors.New("authorized caller not found")

	ErrNamespaceNotFound          = errors.New("namespace not found")
	ErrNamespaceAlreadyRegistered = errors.New("namespace already registered")

	ErrKeyNotFound           = errors.New("key not found")
	ErrWritePermissionDenied = errors.New("write permission denied")
	ErrReadPermissionDenied  = errors.New("read permission denied")
)
