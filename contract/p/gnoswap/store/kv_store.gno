package store

import (
	"chain/runtime"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
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

// Get retrieves a value by key
// Checks read permission before returning the value
func (k *kvStore) Get(key string) (any, error) {
	currentRealm := runtime.CurrentRealm()

	if currentRealm.IsCode() && !k.IsReadAuthorized(currentRealm.Address()) {
		return nil, ErrReadPermissionDenied
	}

	value, exists := k.data[k.makeKey(key)]
	if !exists {
		return nil, ErrKeyNotFound
	}

	return value, nil
}

func (k *kvStore) GetInt64(key string) (int64, error) {
	result, err := k.Get(key)
	if err != nil {
		return 0, err
	}

	return CastToInt64(result)
}

func (k *kvStore) GetUint64(key string) (uint64, error) {
	result, err := k.Get(key)
	if err != nil {
		return 0, err
	}

	return CastToUint64(result)
}

func (k *kvStore) GetBool(key string) (bool, error) {
	result, err := k.Get(key)
	if err != nil {
		return false, err
	}

	return CastToBool(result)
}

func (k *kvStore) GetString(key string) (string, error) {
	result, err := k.Get(key)
	if err != nil {
		return "", err
	}

	return CastToString(result)
}

func (k *kvStore) GetAddress(key string) (address, error) {
	result, err := k.Get(key)
	if err != nil {
		return address(""), err
	}

	return CastToAddress(result)
}

func (k *kvStore) GetTree(key string) (*avl.Tree, error) {
	result, err := k.Get(key)
	if err != nil {
		return nil, err
	}

	return CastToTree(result)
}

// Set stores a value with the given key
// Checks write permission before setting the value
func (k *kvStore) Set(key string, value any) error {
	currentRealm := runtime.CurrentRealm()

	if currentRealm.IsCode() && !k.IsWriteAuthorized(currentRealm.Address()) {
		return ErrWritePermissionDenied
	}

	k.data[k.makeKey(key)] = value

	return nil
}

// Delete removes a key from the store
// Checks write permission before deleting
func (k *kvStore) Delete(key string) error {
	caller := runtime.CurrentRealm().Address()

	if !k.IsWriteAuthorized(caller) {
		return ErrWritePermissionDenied
	}

	if !k.Has(key) {
		return ErrKeyNotFound
	}

	delete(k.data, k.makeKey(key))

	return nil
}

func (k *kvStore) IsDomainAddress(addr address) bool {
	return k.domainAddress == addr
}

// IsReadAuthorized checks if the caller has read permission
func (k *kvStore) IsReadAuthorized(caller address) bool {
	if k.IsDomainAddress(caller) {
		return true
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return false
	}

	return k.authorizedCallers[caller] >= ReadOnly
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
func (k *kvStore) AddAuthorizedCaller(caller address, permission Permission) error {
	if !k.isUpdatableAuthorizedCaller() {
		return ErrUpdatePermissionDenied
	}

	if k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerAlreadyRegistered
	}

	k.authorizedCallers[caller] = permission

	return nil
}

// UpdateAuthorizedCaller updates the permission of an existing authorized caller
func (k *kvStore) UpdateAuthorizedCaller(caller address, permission Permission) error {
	if !k.isUpdatableAuthorizedCaller() {
		return ErrUpdatePermissionDenied
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerNotFound
	}

	k.authorizedCallers[caller] = permission

	return nil
}

// RemoveAuthorizedCaller removes an authorized caller
func (k *kvStore) RemoveAuthorizedCaller(caller address) error {
	if !k.isUpdatableAuthorizedCaller() {
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
func (k *kvStore) isUpdatableAuthorizedCaller() bool {
	currentRealm := runtime.CurrentRealm()

	return currentRealm.Address() == k.domainAddress
}

func (k *kvStore) makeKey(key string) string {
	return ufmt.Sprintf("%s:%s", k.domainAddress, key)
}
