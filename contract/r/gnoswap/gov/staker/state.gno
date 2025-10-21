package staker

import (
	"chain/runtime"
	"errors"

	_ "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	currentAddress = runtime.CurrentRealm().Address()
	domainPath = "gno.land/r/gnoswap/gov/staker"

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IGovStaker
)

func init() {
	// Initialize KVStore
	kvStore = store.NewKVStore(currentAddress)

	// Create VersionManager
	versionManager = version_manager.NewVersionManager(domainPath, kvStore, initializeDomainStore)
	implementation = nil
}

func initializeDomainStore(kvStore store.KVStore) any {
	return NewGovStakerStore(kvStore)
}

// getImplementation returns the current active implementation
func getImplementation() IGovStaker {
	if implementation == nil {
		panic("implementation is not initialized")
	}
	return implementation
}

func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(IGovStaker)
	if !ok {
		return errors.New("impl is not an IGovStaker")
	}

	implementation = impl

	return nil
}