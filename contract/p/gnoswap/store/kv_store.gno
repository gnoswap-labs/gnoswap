package store

import (
	bptree "gno.land/p/nt/bptree/v0"
)

// kvStore represents a domain-specific key-value storage
// Each domain (pool, position, etc.) creates its own kvStore instance
type kvStore struct {
	data              map[string]any // key -> value
	authorizedCallers map[address]Permission
	domainAddress     address
}

// NewKVStore creates a new kvStore instance for a specific domain
// domain: the name of the domain using this store (e.g., "pool", "position")
func NewKVStore(domainAddress address) KVStore {
	return &kvStore{
		data: make(map[string]any),
		authorizedCallers: map[address]Permission{
			domainAddress: Write,
		},
		domainAddress: domainAddress,
	}
}

// GetDomainAddress returns the domain address
func (k *kvStore) GetDomainAddress() address {
	return k.domainAddress
}

// GetAllKeys returns all keys stored in this kvStore
func (k *kvStore) GetAllKeys() ([]string, error) {
	keys := make([]string, 0, len(k.data))

	// Keys are namespace-prefixed (domainAddress:key) by design
	for key := range k.data {
		keys = append(keys, key)
	}

	return keys, nil
}

// Has checks if a key exists in the store
func (k *kvStore) Has(key string) bool {
	_, exists := k.data[k.makeKey(key)]

	return exists
}

// Get retrieves a value by key.
// Reads are public within the package; only writes are gated by the ACL.
func (k *kvStore) Get(key string) (any, error) {
	value, exists := k.data[k.makeKey(key)]
	if !exists {
		return nil, ErrKeyNotFound
	}

	return value, nil
}

// GetInt64 retrieves a value by key and casts it to int64
// Returns ErrFailedCast if the value is not of type int64
func (k *kvStore) GetInt64(key string) (int64, error) {
	result, err := k.Get(key)
	if err != nil {
		return 0, err
	}

	return castToInt64(result)
}

// GetUint64 retrieves a value by key and casts it to uint64
// Returns ErrFailedCast if the value is not of type uint64
func (k *kvStore) GetUint64(key string) (uint64, error) {
	result, err := k.Get(key)
	if err != nil {
		return 0, err
	}

	return castToUint64(result)
}

// GetBool retrieves a value by key and casts it to bool
// Returns ErrFailedCast if the value is not of type bool
func (k *kvStore) GetBool(key string) (bool, error) {
	result, err := k.Get(key)
	if err != nil {
		return false, err
	}

	return castToBool(result)
}

// GetString retrieves a value by key and casts it to string
// Returns ErrFailedCast if the value is not of type string
func (k *kvStore) GetString(key string) (string, error) {
	result, err := k.Get(key)
	if err != nil {
		return "", err
	}

	return castToString(result)
}

// GetAddress retrieves a value by key and casts it to address
// Returns ErrFailedCast if the value is not of type address
func (k *kvStore) GetAddress(key string) (address, error) {
	result, err := k.Get(key)
	if err != nil {
		return address(""), err
	}

	return castToAddress(result)
}

// GetBPTree retrieves a value by key and casts it to *bptree.BPTree
// Returns ErrFailedCast if the value is not of type *bptree.BPTree
func (k *kvStore) GetBPTree(key string) (*bptree.BPTree, error) {
	result, err := k.Get(key)
	if err != nil {
		return nil, err
	}

	return castToBPTree(result)
}

// Set stores a value with the given key.
//
// rlm.IsCurrent() must hold (rejects spoofed/stale realm tokens). When the
// caller is code, rlm.Address() -- the caller realm -- must be in
// the authorized writers set. EOA / user-realm callers (IsCode == false)
// bypass the ACL so deploy and test flows can populate state without prior
// registration.
func (k *kvStore) Set(_ int, rlm realm, key string, value any) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	if rlm.IsCode() && !k.IsWriteAuthorized(rlm.Address()) {
		return ErrWritePermissionDenied
	}

	k.data[k.makeKey(key)] = value

	return nil
}

// Delete removes a key from the store.
//
// Unlike Set, Delete has no IsCode bypass: rlm.Address() is always
// consulted against the ACL. Delete is destructive, so the relaxed path Set
// offers for EOA / test callers is intentionally not extended here.
func (k *kvStore) Delete(_ int, rlm realm, key string) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	caller := rlm.Address()

	if !k.IsWriteAuthorized(caller) {
		return ErrWritePermissionDenied
	}

	if !k.Has(key) {
		return ErrKeyNotFound
	}

	delete(k.data, k.makeKey(key))

	return nil
}

// IsDomainAddress checks if the given address is the domain address
func (k *kvStore) IsDomainAddress(addr address) bool {
	return k.domainAddress == addr
}

// IsWriteAuthorized checks if the caller has write permission
func (k *kvStore) IsWriteAuthorized(caller address) bool {
	if k.IsDomainAddress(caller) {
		return true
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return false
	}

	return k.authorizedCallers[caller] >= Write
}

// GetAuthorizedCallers returns all authorized callers and their permissions
func (k *kvStore) GetAuthorizedCallers() (map[address]Permission, error) {
	if k.authorizedCallers == nil {
		return make(map[address]Permission), ErrAuthorizedCallerNotFound
	}

	return k.authorizedCallers, nil
}

// AddAuthorizedCaller adds a new authorized caller with the specified permission
func (k *kvStore) AddAuthorizedCaller(_ int, rlm realm, caller address, permission Permission) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	if !k.isUpdatableAuthorizedCaller(rlm.Address()) {
		return ErrUpdatePermissionDenied
	}

	if k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerAlreadyRegistered
	}

	if !isValidPermission(permission) {
		return ErrInvalidPermission
	}

	k.authorizedCallers[caller] = permission

	return nil
}

// UpdateAuthorizedCaller updates the permission of an existing authorized caller
func (k *kvStore) UpdateAuthorizedCaller(_ int, rlm realm, caller address, permission Permission) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	if !k.isUpdatableAuthorizedCaller(rlm.Address()) {
		return ErrUpdatePermissionDenied
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerNotFound
	}

	if !isValidPermission(permission) {
		return ErrInvalidPermission
	}

	k.authorizedCallers[caller] = permission

	return nil
}

// RemoveAuthorizedCaller removes an authorized caller
func (k *kvStore) RemoveAuthorizedCaller(_ int, rlm realm, caller address) error {
	if !rlm.IsCurrent() {
		return ErrSpoofedRealm
	}

	if !k.isUpdatableAuthorizedCaller(rlm.Address()) {
		return ErrUpdatePermissionDenied
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerNotFound
	}

	delete(k.authorizedCallers, caller)

	return nil
}

// isRegisteredAuthorizedCaller checks if a caller is registered
func (k *kvStore) isRegisteredAuthorizedCaller(caller address) bool {
	_, exists := k.authorizedCallers[caller]

	return exists
}

// isUpdatableAuthorizedCaller checks if the current realm is the same as the domain address
func (k *kvStore) isUpdatableAuthorizedCaller(currentRealmAddress address) bool {
	return currentRealmAddress == k.domainAddress
}

// makeKey creates a prefixed key with the domain address to ensure isolation
func (k *kvStore) makeKey(key string) string {
	return string(k.domainAddress) + ":" + key
}

// isValidPermission ensures only Write is assignable via registration APIs.
// The zero value is rejected so callers must spell out an explicit permission.
func isValidPermission(permission Permission) bool {
	return permission == Write
}
