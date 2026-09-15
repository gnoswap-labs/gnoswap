package launchpad

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation ILaunchpad
)

// init initializes the launchpad KV store, version manager, and empty implementation slot.
//
// Parameters:
//   - cur: current realm context supplied by the runtime during package initialization.
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

// initializeDomainStore creates the launchpad store implementation for a KV store.
//
// Parameters:
//   - _: cross-call discriminator; callers pass 0.
//   - rlm: propagated realm context associated with the domain-store initialization.
//   - kvStore: key-value store that backs launchpad persistence.
//
// Returns:
//   - store: launchpad store implementation returned as an interface value.
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewLaunchpadStore(kvStore)
}

// getImplementation returns the currently selected launchpad implementation.
//
// Returns:
//   - implementation: active ILaunchpad implementation; panics if version initialization has not selected one.
func getImplementation() ILaunchpad {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation loads the version manager's current implementation into the active slot.
//
// Returns:
//   - err: nil when the current value implements ILaunchpad; non-nil when no implementation is registered or the value has the wrong type.
func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(ILaunchpad)
	if !ok {
		return errors.New("impl is not an ILaunchpad")
	}

	implementation = impl

	return nil
}
