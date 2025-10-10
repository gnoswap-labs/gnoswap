package storage

type Permission uint8

const (
	None     Permission = 0
	ReadOnly Permission = 1
	Write    Permission = 2
)

type KVStore interface {
	GetAllKeys() ([]string, error)

	Has(key string) bool
	Get(key string, caller address) (any, error)
	Set(key string, value any, caller address) error
	Delete(key string, caller address) error

	IsReadAuthorized(caller address) bool
	IsWriteAuthorized(caller address) bool

	GetAuthorizedCallers() (map[address]Permission, error)
	AddAuthorizedCaller(caller address, permission Permission) error
	UpdateAuthorizedCaller(caller address, permission Permission) error
	RemoveAuthorizedCaller(caller address) error
}

type SystemStorage interface {
	GetNamespaceKeys() ([]string, error)

	GetStore(namespace string) (KVStore, error)
	HasStore(namespace string) bool
	RegisterStore(namespace string) error
	RemoveStore(namespace string) error
}
