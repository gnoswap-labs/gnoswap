package store

import (
	bptree "gno.land/p/nt/bptree/v0"
)

type Permission uint8

const (
	_ Permission = iota
	Write
)

// KVStore interface for domain-specific storage
// Each domain creates its own instance of KVStore
type KVStore interface {
	// GetDomainAddress returns the domain address.
	//
	// Returns:
	//   - address: Address of the domain realm that owns this store.
	GetDomainAddress() address

	// GetAllKeys returns all keys in this store.
	//
	// Returns:
	//   - []string: Keys currently stored by the implementation, including any namespace prefix it uses.
	//   - error: nil when keys are enumerated successfully; otherwise the implementation's retrieval error.
	GetAllKeys() ([]string, error)

	// Has checks if a key exists.
	//
	// Parameters:
	//   - key: Logical key to test for presence in the store.
	//
	// Returns:
	//   - bool: true when key has a stored entry; false when no entry exists.
	Has(key string) bool

	// Get retrieves a value by key.
	//
	// Parameters:
	//   - key: Logical key whose stored value should be returned.
	//
	// Returns:
	//   - any: Value stored under key, including an explicitly stored nil.
	//   - error: nil when key exists; otherwise the implementation's missing-key error.
	Get(key string) (any, error)

	// GetInt64 retrieves an int64 value by key.
	//
	// Parameters:
	//   - key: Logical key whose value must have dynamic type int64.
	//
	// Returns:
	//   - int64: Stored int64 value, or the implementation's zero value when retrieval or casting fails.
	//   - error: nil on success; otherwise a missing-key or failed-cast error.
	GetInt64(key string) (int64, error)

	// GetUint64 retrieves a uint64 value by key.
	//
	// Parameters:
	//   - key: Logical key whose value must have dynamic type uint64.
	//
	// Returns:
	//   - uint64: Stored uint64 value, or the implementation's zero value when retrieval or casting fails.
	//   - error: nil on success; otherwise a missing-key or failed-cast error.
	GetUint64(key string) (uint64, error)

	// GetBool retrieves a bool value by key.
	//
	// Parameters:
	//   - key: Logical key whose value must have dynamic type bool.
	//
	// Returns:
	//   - bool: Stored bool value, or false when retrieval or casting fails.
	//   - error: nil on success; otherwise a missing-key or failed-cast error.
	GetBool(key string) (bool, error)

	// GetString retrieves a string value by key.
	//
	// Parameters:
	//   - key: Logical key whose value must have dynamic type string.
	//
	// Returns:
	//   - string: Stored string value, or the empty string when retrieval or casting fails.
	//   - error: nil on success; otherwise a missing-key or failed-cast error.
	GetString(key string) (string, error)

	// GetAddress retrieves an address value by key.
	//
	// Parameters:
	//   - key: Logical key whose value must have dynamic type address.
	//
	// Returns:
	//   - address: Stored address value, or the empty address when retrieval or casting fails.
	//   - error: nil on success; otherwise a missing-key or failed-cast error.
	GetAddress(key string) (address, error)

	// GetBPTree retrieves a B+ tree value by key.
	//
	// Parameters:
	//   - key: Logical key whose value must have dynamic type *bptree.BPTree.
	//
	// Returns:
	//   - *bptree.BPTree: Stored B+ tree pointer, or nil when retrieval or casting fails.
	//   - error: nil on success; otherwise a missing-key or failed-cast error.
	GetBPTree(key string) (*bptree.BPTree, error)

	// Set stores a value with the given key.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate it and may use its address for write authorization.
	//   - key: Logical key under which value is stored.
	//   - value: Arbitrary value to associate with key.
	//
	// Returns:
	//   - error: nil when value is stored; otherwise the implementation's realm, authorization, or storage error.
	Set(_ int, rlm realm, key string, value any) error

	// Delete removes a key.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate it and may use its address for write authorization.
	//   - key: Logical key whose stored entry should be removed.
	//
	// Returns:
	//   - error: nil when key is removed; otherwise the implementation's realm, authorization, missing-key, or storage error.
	Delete(_ int, rlm realm, key string) error

	// IsWriteAuthorized checks if the caller has write permission.
	//
	// Parameters:
	//   - caller: Address whose write permission should be checked.
	//
	// Returns:
	//   - bool: true when caller is authorized to write; false otherwise.
	IsWriteAuthorized(caller address) bool

	// GetAuthorizedCallers returns all authorized callers and their permissions.
	//
	// Returns:
	//   - map[address]Permission: Caller-to-permission mapping exposed by the implementation.
	//   - error: nil when the ACL is available; otherwise the implementation's ACL retrieval error.
	GetAuthorizedCallers() (map[address]Permission, error)

	// AddAuthorizedCaller adds a new authorized caller.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate it before changing ACL state.
	//   - caller: Address to add to the authorization map.
	//   - permission: Permission to assign to caller; the concrete store accepts Write.
	//
	// Returns:
	//   - error: nil when caller is added; otherwise the implementation's realm, authorization, duplicate, permission, or storage error.
	AddAuthorizedCaller(_ int, rlm realm, caller address, permission Permission) error

	// UpdateAuthorizedCaller updates an existing caller's permission.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate it before changing ACL state.
	//   - caller: Address of the registered caller to update.
	//   - permission: Replacement permission for caller; the concrete store accepts Write.
	//
	// Returns:
	//   - error: nil when caller's permission is updated; otherwise the implementation's realm, authorization, missing-caller, permission, or storage error.
	UpdateAuthorizedCaller(_ int, rlm realm, caller address, permission Permission) error

	// RemoveAuthorizedCaller removes an authorized caller.
	//
	// Parameters:
	//   - _: Interrealm-call discriminator; callers pass 0.
	//   - rlm: Propagated current realm context from the domain wrapper; implementations validate it before changing ACL state.
	//   - caller: Address of the registered caller to remove.
	//
	// Returns:
	//   - error: nil when caller is removed; otherwise the implementation's realm, authorization, missing-caller, or storage error.
	RemoveAuthorizedCaller(_ int, rlm realm, caller address) error
}
