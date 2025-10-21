package staker

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	// VersionManager manages different implementations
	vm       *version_manager.VersionManager
	kvStore  store.KVStore
	instance IGovStaker // Current active implementation
)

const (
	domainPath = "gno.land/r/gnoswap/gov/staker"
)

func init() {
	// Initialize KVStore
	kvStore = store.New()

	// Create VersionManager
	vm = version_manager.NewInstance(domainPath, kvStore)
}

// getImplementation returns the current active implementation
func getImplementation() IGovStaker {
	return instance
}

// setImplementation sets the active implementation
func setImplementation(impl IGovStaker) {
	instance = impl
}
