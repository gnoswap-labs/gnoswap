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

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewPositionStore(kvStore)
}

func getImplementation() IPosition {
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

	impl, ok := result.(IPosition)
	if !ok {
		return errors.New("impl is not an IPosition")
	}

	implementation = impl

	return nil
}
