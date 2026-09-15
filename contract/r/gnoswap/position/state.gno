package position

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	domainPath = "gno.land/r/gnoswap/position"

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IPosition
)

// init initializes the position realm's KV store and version manager.
//
// Parameters:
//   - cur: runtime-supplied current realm context used to derive this realm's address and package path
func init(cur realm) {
	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(cur.Address())

	// Initialize the initializers map to store implementation registration functions
	versionManager = version_manager.NewVersionManager(
		cur.PkgPath(),
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

// initializeDomainStore constructs the position store for a registered implementation.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context supplied by the version manager
//   - kvStore: key-value store scoped to the position realm
//
// Returns:
//   - store: newly initialized position store, returned as an any value for version-manager registration
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewPositionStore(kvStore)
}

// getImplementation returns the currently selected position implementation.
//
// Returns:
//   - implementation: active IPosition implementation; panics if no implementation has been initialized
func getImplementation() IPosition {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation selects the current versioned implementation and stores it for dispatch.
//
// Returns:
//   - err: nil when the current implementation is an IPosition; non-nil when no implementation is registered or the value has the wrong type
func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(IPosition)
	if !ok {
		return errors.New("impl is not an IPosition")
	}

	implementation = impl

	return nil
}
