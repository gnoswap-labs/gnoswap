package router

import (
	"chain/runtime"
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	"gno.land/r/gnoswap/access"
)

var (
	currentAddress = runtime.CurrentRealm().Address()
	domainPath     = runtime.CurrentRealm().PkgPath()

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IRouter
)

func init() {
	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(currentAddress)
	initRegisterReadableContract()

	// Initialize the initializers map to store implementation registration functions
	versionManager = version_manager.NewVersionManager(
		domainPath,
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

func initRegisterReadableContract() {
	govStakerAddress := access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	kvStore.AddAuthorizedCaller(govStakerAddress, store.ReadOnly)
}

func initializeDomainStore(kvStore store.KVStore) any {
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
