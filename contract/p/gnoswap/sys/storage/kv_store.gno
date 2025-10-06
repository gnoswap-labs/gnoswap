package storage

// kvStore represents the core key-value storage system
type kvStore struct {
	data              map[string]any // key -> value
	authorizedCallers map[address]Permission
}

// NewKVStore creates a new kvStore instance
func NewKVStore() KVStore {
	return &kvStore{
		data:              make(map[string]any),
		authorizedCallers: make(map[address]Permission),
	}
}

func (k *kvStore) GetAllKeys() ([]string, error) {
	keys := make([]string, 0, len(k.data))

	for key := range k.data {
		keys = append(keys, key)
	}

	return keys, nil
}

// Has checks if a key exists in the specified namespace
func (k *kvStore) Has(key string) bool {
	_, exists := k.data[key]
	if !exists {
		return false
	}

	return exists
}

// Get retrieves a value from the specified namespace and key
func (k *kvStore) Get(key string, caller address) (any, error) {
	if !k.IsReadAuthorized(caller) {
		return nil, ErrReadPermissionDenied
	}

	value, exists := k.data[key]
	if !exists {
		return nil, ErrKeyNotFound
	}

	return value, nil
}

// Set stores a value in the specified namespace and key
func (k *kvStore) Set(key string, value any, caller address) error {
	if !k.IsWriteAuthorized(caller) {
		return ErrWritePermissionDenied
	}

	// Store the value
	k.data[key] = value

	return nil
}

// Delete removes a key from the specified namespace
func (k *kvStore) Delete(key string, caller address) error {
	if !k.IsWriteAuthorized(caller) {
		return ErrWritePermissionDenied
	}

	if !k.Has(key) {
		return ErrKeyNotFound
	}

	// Delete the key
	delete(k.data, key)

	return nil
}

func (k *kvStore) IsReadAuthorized(caller address) bool {
	if !k.isRegisteredAuthorizedCaller(caller) {
		return false
	}

	return k.authorizedCallers[caller] >= ReadOnly
}

func (k *kvStore) IsWriteAuthorized(caller address) bool {
	if !k.isRegisteredAuthorizedCaller(caller) {
		return false
	}

	return k.authorizedCallers[caller] >= Write
}

func (k *kvStore) GetAuthorizedCallers() (map[address]Permission, error) {
	if k.authorizedCallers == nil {
		return make(map[address]Permission), ErrAuthorizedCallerNotFound
	}

	return k.authorizedCallers, nil
}

func (k *kvStore) AddAuthorizedCaller(caller address, permission Permission) error {
	if k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerAlreadyRegistered
	}

	k.authorizedCallers[caller] = permission

	return nil
}

func (k *kvStore) UpdateAuthorizedCaller(caller address, permission Permission) error {
	if !k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerNotFound
	}

	k.authorizedCallers[caller] = permission

	return nil
}

func (k *kvStore) RemoveAuthorizedCaller(caller address) error {
	if !k.isRegisteredAuthorizedCaller(caller) {
		return ErrAuthorizedCallerNotFound
	}

	delete(k.authorizedCallers, caller)

	return nil
}

func (k *kvStore) isRegisteredAuthorizedCaller(caller address) bool {
	_, exists := k.authorizedCallers[caller]

	return exists
}
