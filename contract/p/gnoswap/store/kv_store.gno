package store

import (
	"errors"

	bptree "gno.land/p/nt/bptree/v0"
)

// kvStore represents a domain-specific key-value storage
// Each domain (pool, position, etc.) creates its own kvStore instance
type kvStore struct {
	data              map[string]any // key -> value
	authorizedCallers map[address]Permission
	domainAddress     address
}

// NewKVStore creates a new kvStore instance for a specific domain.
// domainAddress is the address of the domain realm that owns this store.
//
// Parameters:
//   - domainAddress: Address of the owning domain realm; it is initially granted Write permission.
//
// Returns:
//   - KVStore: Empty domain-isolated store whose ACL initially authorizes domainAddress for writes.
func NewKVStore(domainAddress address) KVStore {
	return &kvStore{
		data: make(map[string]any),
		authorizedCallers: map[address]Permission{
			domainAddress: Write,
		},
		domainAddress: domainAddress,
	}
}

// GetDomainAddress returns the domain address.
//
// Returns:
//   - address: Address of the domain realm that owns this store.
func (k *kvStore) GetDomainAddress() address {
	return k.domainAddress
}

// GetAllKeys returns all keys stored in this kvStore.
//
// Returns:
//   - []string: Stored keys including the domain-address namespace prefix; map iteration order is unspecified.
//   - error: Always nil for this in-memory implementation.
func (k *kvStore) GetAllKeys() ([]string, error) {
	keys := make([]string, 0, len(k.data))

	// Keys are namespace-prefixed (domainAddress:key) by design
	for key := range k.data {
		keys = append(keys, key)
	}

	return keys, nil
}

// Has checks if a key exists in the store.
//
// Parameters:
//   - key: Logical key to check; the store applies its domain namespace prefix before lookup.
//
// Returns:
//   - bool: true when the namespaced key is present, including when its stored value is nil; false otherwise.
func (k *kvStore) Has(key string) bool {
	_, exists := k.data[k.makeKey(key)]

	return exists
}

// Get retrieves a value by key.
// Reads are public within the package; only writes are gated by the ACL.
// Realms exposing sensitive values must enforce their own read policy before
// calling into the store.
//
// Parameters:
//   - key: Logical key whose namespaced entry should be retrieved.
//
// Returns:
//   - any: Stored value, including an explicitly stored nil, or nil when key is absent.
//   - error: nil when key exists; otherwise ErrKeyNotFound.
func (k *kvStore) Get(key string) (any, error) {
	value, exists := k.data[k.makeKey(key)]
	if !exists {
		return nil, errors.New(ErrKeyNotFound)
	}

	return value, nil
}

// GetInt64 retrieves a value by key and casts it to int64.
// Returns ErrFailedCast if the value is not of type int64.
//
// Parameters:
//   - key: Logical key whose stored value must have dynamic type int64.
//
// Returns:
//   - int64: Stored int64 value, or 0 when the key is absent or has another type.
//   - error: nil on success; otherwise ErrKeyNotFound or ErrFailedCast.
func (k *kvStore) GetInt64(key string) (int64, error) {
	result, err := k.Get(key)
	if err != nil {
		return 0, err
	}

	return castToInt64(result)
}

// GetUint64 retrieves a value by key and casts it to uint64.
// Returns ErrFailedCast if the value is not of type uint64.
//
// Parameters:
//   - key: Logical key whose stored value must have dynamic type uint64.
//
// Returns:
//   - uint64: Stored uint64 value, or 0 when the key is absent or has another type.
//   - error: nil on success; otherwise ErrKeyNotFound or ErrFailedCast.
func (k *kvStore) GetUint64(key string) (uint64, error) {
	result, err := k.Get(key)
	if err != nil {
		return 0, err
	}

	return castToUint64(result)
}

// GetBool retrieves a value by key and casts it to bool.
// Returns ErrFailedCast if the value is not of type bool.
//
// Parameters:
//   - key: Logical key whose stored value must have dynamic type bool.
//
// Returns:
//   - bool: Stored bool value, or false when the key is absent or has another type.
//   - error: nil on success; otherwise ErrKeyNotFound or ErrFailedCast.
func (k *kvStore) GetBool(key string) (bool, error) {
	result, err := k.Get(key)
	if err != nil {
		return false, err
	}

	return castToBool(result)
}

// GetString retrieves a value by key and casts it to string.
// Returns ErrFailedCast if the value is not of type string.
//
// Parameters:
//   - key: Logical key whose stored value must have dynamic type string.
//
// Returns:
//   - string: Stored string value, or the empty string when the key is absent or has another type.
//   - error: nil on success; otherwise ErrKeyNotFound or ErrFailedCast.
func (k *kvStore) GetString(key string) (string, error) {
	result, err := k.Get(key)
	if err != nil {
		return "", err
	}

	return castToString(result)
}

// GetAddress retrieves a value by key and casts it to address.
// Returns ErrFailedCast if the value is not of type address.
//
// Parameters:
//   - key: Logical key whose stored value must have dynamic type address.
//
// Returns:
//   - address: Stored address value, or the empty address when the key is absent or has another type.
//   - error: nil on success; otherwise ErrKeyNotFound or ErrFailedCast.
func (k *kvStore) GetAddress(key string) (address, error) {
	result, err := k.Get(key)
	if err != nil {
		return address(""), err
	}

	return castToAddress(result)
}

// GetBPTree retrieves a value by key and casts it to *bptree.BPTree.
// Returns ErrFailedCast if the value is not of type *bptree.BPTree.
//
// Parameters:
//   - key: Logical key whose stored value must have dynamic type *bptree.BPTree.
//
// Returns:
//   - *bptree.BPTree: Stored B+ tree pointer, or nil when the key is absent or has another type.
//   - error: nil on success; otherwise ErrKeyNotFound or ErrFailedCast.
func (k *kvStore) GetBPTree(key string) (*bptree.BPTree, error) {
	result, err := k.Get(key)
	if err != nil {
		return nil, err
	}

	return castToBPTree(result)
}

// Set stores a value with the given key.
//
// Parameters:
//   - _: Interrealm-call discriminator; callers pass 0.
//   - rlm: Propagated current realm context from the domain wrapper; this implementation validates rlm.IsCurrent() and uses rlm.Address() for code-caller write authorization.
//   - key: Logical key under which value is stored; the store adds its domain namespace prefix.
//   - value: Arbitrary value to store under key.
//
// Returns:
//   - error: nil when value is stored; otherwise ErrSpoofedRealm or ErrWritePermissionDenied.
func (k *kvStore) Set(_ int, rlm realm, key string, value any) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if rlm.IsCode() && !k.IsWriteAuthorized(rlm.Address()) {
		return errors.New(ErrWritePermissionDenied)
	}

	k.data[k.makeKey(key)] = value

	return nil
}

// Delete removes a key from the store.
//
// Parameters:
//   - _: Interrealm-call discriminator; callers pass 0.
//   - rlm: Propagated current realm context from the domain wrapper; this implementation validates rlm.IsCurrent() and uses rlm.Address() for code-caller write authorization.
//   - key: Logical key whose namespaced entry should be removed.
//
// Returns:
//   - error: nil when key is removed; otherwise ErrSpoofedRealm, ErrWritePermissionDenied, or ErrKeyNotFound.
func (k *kvStore) Delete(_ int, rlm realm, key string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if rlm.IsCode() && !k.IsWriteAuthorized(rlm.Address()) {
		return errors.New(ErrWritePermissionDenied)
	}

	if !k.Has(key) {
		return errors.New(ErrKeyNotFound)
	}

	delete(k.data, k.makeKey(key))

	return nil
}

// IsDomainAddress checks if the given address is the domain address.
//
// Parameters:
//   - addr: Address to compare with the store's owning domain address.
//
// Returns:
//   - bool: true when addr equals the owning domain address; false otherwise.
func (k *kvStore) IsDomainAddress(addr address) bool {
	return k.domainAddress == addr
}

// IsWriteAuthorized checks if the caller has write permission.
//
// Parameters:
//   - caller: Address whose write permission should be evaluated.
//
// Returns:
//   - bool: true for the domain address or a registered caller with Write permission; false otherwise.
func (k *kvStore) IsWriteAuthorized(caller address) bool {
	if k.IsDomainAddress(caller) {
		return true
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return false
	}

	return k.authorizedCallers[caller] >= Write
}

// GetAuthorizedCallers returns a copy of the authorized callers map with their permissions.
// A copy is returned so callers cannot mutate the ACL map directly.
//
// Returns:
//   - map[address]Permission: Newly allocated snapshot of registered caller permissions.
//   - error: nil when the ACL map exists; otherwise ErrAuthorizedCallerNotFound.
func (k *kvStore) GetAuthorizedCallers() (map[address]Permission, error) {
	if k.authorizedCallers == nil {
		return make(map[address]Permission), errors.New(ErrAuthorizedCallerNotFound)
	}

	out := make(map[address]Permission, len(k.authorizedCallers))
	for addr, perm := range k.authorizedCallers {
		out[addr] = perm
	}
	return out, nil
}

// AddAuthorizedCaller adds a new authorized caller with the specified permission.
//
// Parameters:
//   - _: Interrealm-call discriminator; callers pass 0.
//   - rlm: Propagated current realm context from the domain wrapper; this implementation validates rlm.IsCurrent() and requires its address to be the owning domain for ACL updates.
//   - caller: Address to add to the write-authorization map.
//   - permission: Permission to assign; registration APIs accept only Write.
//
// Returns:
//   - error: nil when caller is added; otherwise ErrSpoofedRealm, ErrUpdatePermissionDenied, ErrAuthorizedCallerAlreadyRegistered, or ErrInvalidPermission.
func (k *kvStore) AddAuthorizedCaller(_ int, rlm realm, caller address, permission Permission) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !k.isUpdatableAuthorizedCaller(rlm.Address()) {
		return errors.New(ErrUpdatePermissionDenied)
	}

	if k.isRegisteredAuthorizedCaller(caller) {
		return errors.New(ErrAuthorizedCallerAlreadyRegistered)
	}

	if !isValidPermission(permission) {
		return errors.New(ErrInvalidPermission)
	}

	k.authorizedCallers[caller] = permission

	return nil
}

// UpdateAuthorizedCaller updates the permission of an existing authorized caller.
//
// Parameters:
//   - _: Interrealm-call discriminator; callers pass 0.
//   - rlm: Propagated current realm context from the domain wrapper; this implementation validates rlm.IsCurrent() and requires its address to be the owning domain for ACL updates.
//   - caller: Address of the already registered caller whose permission should change.
//   - permission: Replacement permission; registration APIs accept only Write.
//
// Returns:
//   - error: nil when caller's permission is updated; otherwise ErrSpoofedRealm, ErrUpdatePermissionDenied, ErrAuthorizedCallerNotFound, or ErrInvalidPermission.
func (k *kvStore) UpdateAuthorizedCaller(_ int, rlm realm, caller address, permission Permission) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !k.isUpdatableAuthorizedCaller(rlm.Address()) {
		return errors.New(ErrUpdatePermissionDenied)
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return errors.New(ErrAuthorizedCallerNotFound)
	}

	if !isValidPermission(permission) {
		return errors.New(ErrInvalidPermission)
	}

	k.authorizedCallers[caller] = permission

	return nil
}

// RemoveAuthorizedCaller removes an authorized caller.
//
// Parameters:
//   - _: Interrealm-call discriminator; callers pass 0.
//   - rlm: Propagated current realm context from the domain wrapper; this implementation validates rlm.IsCurrent() and requires its address to be the owning domain for ACL updates.
//   - caller: Address of the registered caller to remove.
//
// Returns:
//   - error: nil when caller is removed; otherwise ErrSpoofedRealm, ErrUpdatePermissionDenied, or ErrAuthorizedCallerNotFound.
func (k *kvStore) RemoveAuthorizedCaller(_ int, rlm realm, caller address) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !k.isUpdatableAuthorizedCaller(rlm.Address()) {
		return errors.New(ErrUpdatePermissionDenied)
	}

	if !k.isRegisteredAuthorizedCaller(caller) {
		return errors.New(ErrAuthorizedCallerNotFound)
	}

	delete(k.authorizedCallers, caller)

	return nil
}

// isRegisteredAuthorizedCaller checks if a caller is registered.
//
// Parameters:
//   - caller: Address to look up in the authorized-caller map.
//
// Returns:
//   - bool: true when caller has an ACL entry, regardless of its permission value; false otherwise.
func (k *kvStore) isRegisteredAuthorizedCaller(caller address) bool {
	_, exists := k.authorizedCallers[caller]

	return exists
}

// isUpdatableAuthorizedCaller checks if the current realm is the same as the domain address.
//
// Parameters:
//   - currentRealmAddress: Address of the realm requesting an ACL update.
//
// Returns:
//   - bool: true when currentRealmAddress equals the store's domain address; false otherwise.
func (k *kvStore) isUpdatableAuthorizedCaller(currentRealmAddress address) bool {
	return currentRealmAddress == k.domainAddress
}

// makeKey creates a prefixed key with the domain address to ensure isolation.
//
// Parameters:
//   - key: Logical key supplied by a caller.
//
// Returns:
//   - string: Namespaced key formed by concatenating the domain address, a colon, and key.
func (k *kvStore) makeKey(key string) string {
	return string(k.domainAddress) + ":" + key
}

// isValidPermission ensures only Write is assignable via registration APIs.
// The zero value is rejected so callers must spell out an explicit permission.
//
// Parameters:
//   - permission: Permission value proposed for an authorized caller.
//
// Returns:
//   - bool: true only for Write; false for the zero value or any other permission.
func isValidPermission(permission Permission) bool {
	return permission == Write
}
