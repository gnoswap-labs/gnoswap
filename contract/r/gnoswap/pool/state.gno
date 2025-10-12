package pool

import (
	"chain/runtime"

	"gno.land/p/gnoswap/store"
)

var (
	// kvStore is the core storage instance for the pool domain.
	// All pool implementations share this single storage instance,
	// ensuring data consistency across version upgrades.
	kvStore store.KVStore

	// poolImpl is the currently active pool implementation.
	// This pointer is switched during upgrades to point to different versions (v1, v2, etc.).
	// The proxy layer routes all calls to this implementation.
	poolImpl IPool

	// initializers maps package paths to their initialization functions.
	// This allows the upgrade system to create instances of any registered implementation.
	// Key: package path (e.g., "gno.land/r/gnoswap/pool/v1")
	// Value: function that creates a new instance of that implementation
	initializers map[string]func(poolStore IPoolStore) IPool
)

// init initializes the pool domain state.
// This function is called when the pool domain contract is first deployed.
func init() {
	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())

	// Initialize the initializers map to store implementation registration functions
	initializers = make(map[string]func(poolStore IPoolStore) IPool)
}
