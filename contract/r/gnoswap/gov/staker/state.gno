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

// init initializes the gov/staker realm's address, persistent store, and version manager.
//
// Parameters:
//   - cur: realm context supplied by the runtime during package initialization; it identifies this realm.
func init(cur realm) {
	currentAddress = cur.Address()

	// Initialize KVStore
	kvStore = store.NewKVStore(currentAddress)

	// Create VersionManager
	versionManager = version_manager.NewVersionManager(domainPath, kvStore, initializeDomainStore)
	implementation = nil
}

// initializeDomainStore creates the domain store used by the version manager.
//
// Parameters:
//   - _: leading version-manager call discriminator; callers pass 0.
//   - rlm: forwarded realm context from the version manager; this initializer does not inspect it.
//   - kvStore: key-value store owned by the gov/staker realm.
//
// Returns:
//   - any: newly initialized gov/staker store value.
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewGovStakerStore(kvStore)
}

// getImplementation returns the active gov/staker implementation.
// It panics when updateImplementation has not installed one.
//
// Returns:
//   - IGovStaker: currently selected implementation.
func getImplementation() IGovStaker {
	if implementation == nil {
		panic("implementation is not initialized")
	}
	return implementation
}

// updateImplementation loads and type-checks the version manager's current implementation.
//
// Returns:
//   - error: nil when an IGovStaker implementation is installed; otherwise an initialization or type error.
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
