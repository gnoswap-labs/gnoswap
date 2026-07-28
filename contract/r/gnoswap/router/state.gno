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

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewRouterStore(kvStore)
}

func getImplementation() IRouter {
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

	impl, ok := result.(IRouter)
	if !ok {
		return errors.New("impl is not an IRouter")
	}

	implementation = impl

	return nil
}
