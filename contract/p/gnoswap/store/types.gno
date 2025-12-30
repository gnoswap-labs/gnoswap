package store

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/avl/rotree"
)

type Permission uint8

const (
	_ Permission = iota
	ReadOnly
	Write
)

// KVStore interface for domain-specific storage
// Each domain creates its own instance of KVStore
type KVStore interface {
	// GetDomainAddress returns the domain address
	GetDomainAddress() address

	// GetAllKeys returns all keys in this store
	GetAllKeys() ([]string, error)

	// Has checks if a key exists
	Has(key string) bool

	// Get retrieves a value by key
	Get(key string) (any, error)

	// GetInt64 retrieves a int64 value by key
	GetInt64(key string) (int64, error)

	// GetUint64 retrieves a uint64 value by key
	GetUint64(key string) (uint64, error)

	// GetBool retrieves a bool value by key
	GetBool(key string) (bool, error)

	// GetString retrieves a string value by key
	GetString(key string) (string, error)

	// GetAddress retrieves an address value by key
	GetAddress(key string) (address, error)

	// GetTree retrieves a tree value by key
	GetTree(key string) (*avl.Tree, error)

	// Set stores a value with the given key
	Set(key string, value any) error

	// Delete removes a key
	Delete(key string) error

	// IsReadAuthorized checks if the caller has read permission
	IsReadAuthorized(caller address) bool

	// IsWriteAuthorized checks if the caller has write permission
	IsWriteAuthorized(caller address) bool

	// GetAuthorizedCallers returns all authorized callers and their permissions
	GetAuthorizedCallers() (map[address]Permission, error)

	// AddAuthorizedCaller adds a new authorized caller
	AddAuthorizedCaller(caller address, permission Permission) error

	// UpdateAuthorizedCaller updates an existing caller's permission
	UpdateAuthorizedCaller(caller address, permission Permission) error

	// RemoveAuthorizedCaller removes an authorized caller
	RemoveAuthorizedCaller(caller address) error
}
