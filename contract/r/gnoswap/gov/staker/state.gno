package staker

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	// Package-init reads use chain/runtime/unsafe.CurrentRealm because there
	// is no `cur realm` in scope at package-initialization time. The values
	// captured here describe the gov/staker realm itself, not any caller.
	currentAddress address
	domainPath     = "gno.land/r/gnoswap/gov/staker"

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IGovStaker
)

func init(cur realm) {
	currentAddress = cur.Address()

	// Initialize KVStore
	kvStore = store.NewKVStore(currentAddress)

	// Create VersionManager
	versionManager = version_manager.NewVersionManager(domainPath, kvStore, initializeDomainStore)
	implementation = nil
}

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
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
