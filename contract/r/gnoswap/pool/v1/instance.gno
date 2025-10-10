package pool

import (
	"gno.land/p/gnoswap/sys/storage"
)

// Global PoolV1 instance
var poolV1 *PoolV1

// InitializePool initializes the pool with a KVStore
// This should be called once during contract initialization
func InitializePool(store storage.KVStore) {
	if poolV1 != nil {
		panic("pool already initialized")
	}
	poolV1 = NewPoolV1(store)
}

// GetPoolInstance returns the initialized PoolV1 instance
func GetPoolInstance() *PoolV1 {
	if poolV1 == nil {
		panic("pool not initialized - call InitializePool first")
	}
	return poolV1
}

// MustHavePoolInstance ensures pool is initialized
func MustHavePoolInstance() {
	if poolV1 == nil {
		panic("pool not initialized")
	}
}
