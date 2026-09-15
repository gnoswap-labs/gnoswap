package pool

import (
	"errors"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	// initialize rbac roles
	_ "gno.land/r/gnoswap/rbac"
)

var (
	domainPath string

	currentAddress address

	// kvStore is the core storage instance for the pool domain.
	// All pool implementations share this single storage instance,
	// ensuring data consistency across version upgrades.
	kvStore store.KVStore

	// versionManager is the version manager for the pool domain.
	// It manages the registration and switching of pool implementations.
	versionManager version_manager.VersionManager

	// implementation is the currently active pool implementation.
	// This pointer is switched during upgrades to point to different versions (v1, v2, etc.).
	// The proxy layer routes all calls to this implementation.
	implementation IPool
)

// init initializes the pool domain state.
// This function is called when the pool domain contract is first deployed.
//
// Parameters:
//   - cur: Realm context supplied by the runtime during domain initialization;
//     its package path and address identify this pool domain.
func init(cur realm) {
	domainPath = cur.PkgPath()
	currentAddress = cur.Address()

	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(currentAddress)

	// Initialize the initializers map to store implementation registration functions
	versionManager = version_manager.NewVersionManager(
		domainPath,
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

// initializeDomainStore wraps the shared key-value store in the pool-specific
// storage interface used by each pool implementation.
//
// Parameters:
//   - _: Leading integer discriminator for the forwarded realm call; callers
//     pass 0.
//   - rlm: Propagated realm context supplied to the implementation initializer;
//     a later cross-realm call must use this current context.
//   - kvStore: Shared key-value store containing state for all pool versions.
//
// Returns:
//   - any: A *PoolStore wrapper around kvStore, returned through the generic
//     version-manager factory interface.
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewPoolStore(kvStore)
}

// getImplementation returns the currently active pool implementation.
// This function is used by all proxy functions to route calls to the active implementation.
// If no implementation is set, it panics to prevent invalid state.
//
// Returns:
//   - IPool: Currently active implementation used by proxy calls; panics when
//     no implementation has been registered.
func getImplementation() IPool {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation refreshes the proxy pointer from the version manager's
// active implementation.
//
// Returns:
//   - error: Nil after the active value is type-asserted to IPool and stored;
//     non-nil when no implementation exists or the active value has another type.
func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(IPool)
	if !ok {
		return errors.New("impl is not an IPool")
	}

	implementation = impl

	return nil
}
