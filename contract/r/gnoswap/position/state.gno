package position

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
	implementation IPosition
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
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())

	if err := kvStore.AddAuthorizedCaller(poolAddr, store.ReadOnly); err != nil {
		panic(err)
	}
	if err := kvStore.AddAuthorizedCaller(stakerAddr, store.ReadOnly); err != nil {
		panic(err)
	}
}

func initializeDomainStore(kvStore store.KVStore) any {
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
