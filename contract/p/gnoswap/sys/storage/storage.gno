package storage

// systemStorage provides the main interface to the storage system
type systemStorage struct {
	namespaceStore map[string]KVStore // namespace -> KVStore
}

// NewSystemStorage creates a new system storage instance
func NewSystemStorage() SystemStorage {
	namespaceStore := make(map[string]KVStore)

	// Initialize with default namespaces
	storage := &systemStorage{
		namespaceStore: namespaceStore,
	}

	return storage
}

func (ss *systemStorage) GetNamespaceKeys() ([]string, error) {
	keys := make([]string, 0, len(ss.namespaceStore))

	for key := range ss.namespaceStore {
		keys = append(keys, key)
	}

	return keys, nil
}

func (ss *systemStorage) GetStore(namespace string) (KVStore, error) {
	store, exists := ss.namespaceStore[namespace]
	if !exists {
		return nil, ErrNamespaceNotFound
	}

	return store, nil
}

func (ss *systemStorage) HasStore(namespace string) bool {
	_, exists := ss.namespaceStore[namespace]

	return exists
}

func (ss *systemStorage) RegisterStore(namespace string) error {
	if ss.HasStore(namespace) {
		return ErrNamespaceAlreadyRegistered
	}

	ss.namespaceStore[namespace] = NewKVStore()

	return nil
}

func (ss *systemStorage) RemoveStore(namespace string) error {
	if !ss.HasStore(namespace) {
		return ErrNamespaceNotFound
	}

	delete(ss.namespaceStore, namespace)

	return nil
}
