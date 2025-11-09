package staker

import (
	"chain/runtime"
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	"gno.land/r/gnoswap/access"
)

var (
	currentAddress = runtime.CurrentRealm().Address()
	domainPath     = runtime.CurrentRealm().PkgPath()

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IStaker
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
	poolAddr := access.MustGetAddress(prbac.ROLE_POOL.String())
	positionAddr := access.MustGetAddress(prbac.ROLE_POSITION.String())
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	emissionAddr := access.MustGetAddress(prbac.ROLE_EMISSION.String())

	if err := kvStore.AddAuthorizedCaller(poolAddr, store.ReadOnly); err != nil {
		panic(err)
	}
	if err := kvStore.AddAuthorizedCaller(positionAddr, store.ReadOnly); err != nil {
		panic(err)
	}
	if err := kvStore.AddAuthorizedCaller(routerAddr, store.ReadOnly); err != nil {
		panic(err)
	}
	if err := kvStore.AddAuthorizedCaller(emissionAddr, store.ReadOnly); err != nil {
		panic(err)
	}
}

func initializeDomainStore(kvStore store.KVStore) any {
	return NewStakerStore(kvStore)
}

func getImplementation() IStaker {
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

	impl, ok := result.(IStaker)
	if !ok {
		return errors.New("impl is not an IStaker")
	}

	implementation = impl

	return nil
}
