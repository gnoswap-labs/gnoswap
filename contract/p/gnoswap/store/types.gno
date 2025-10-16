package store

type Permission uint8

const (
	None     Permission = 0
	ReadOnly Permission = 1
	Write    Permission = 2
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
