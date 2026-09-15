package router

import (
	"chain"
	"errors"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

const domainPath = "gno.land/r/gnoswap/router"

var (
	currentAddress = chain.PackageAddress(domainPath)

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IRouter
)

// init creates the router's persistent store, version manager, and empty implementation slot.
func init() {
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

// initializeDomainStore adapts the version manager callback to the router store constructor.
//
// Parameters:
//   - _: leading callback discriminator; callers pass 0
//   - rlm: propagated realm context supplied by the version manager callback; the store constructor does not inspect it
//   - kvStore: persistent KV store to wrap for router state
//
// Returns:
//   - domainStore: router store implementation held as any for the version manager
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewRouterStore(kvStore)
}

// getImplementation returns the currently selected router implementation.
//
// Returns:
//   - implementation: active IRouter implementation; panics until an implementation has been registered
func getImplementation() IRouter {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation loads the version manager's active implementation into the router state.
//
// Returns:
//   - err: nil when the current implementation satisfies IRouter; an error when none is registered or its type is incompatible
func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(IRouter)
	if !ok {
		return errors.New("impl is not an IRouter")
	}

	implementation = impl

	return nil
}
