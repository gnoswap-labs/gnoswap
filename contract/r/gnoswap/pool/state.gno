package pool

import (
	"chain"
	"chain/runtime"
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
	"gno.land/r/gnoswap/access"

	// initialize rbac roles
	_ "gno.land/r/gnoswap/rbac"
)

var (
	currentAddress = runtime.CurrentRealm().Address()
	domainPath     = runtime.CurrentRealm().PkgPath()

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
	positionAddr := access.MustGetAddress(prbac.ROLE_POSITION.String())
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	routerAddr := access.MustGetAddress(prbac.ROLE_ROUTER.String())
	dustConverterAddr := chain.PackageAddress("gno.land/r/gnoswap/dust_converter")

	if err := kvStore.AddAuthorizedCaller(routerAddr, store.ReadOnly); err != nil {
		panic(err)
	}

	if err := kvStore.AddAuthorizedCaller(positionAddr, store.ReadOnly); err != nil {
		panic(err)
	}

	if err := kvStore.AddAuthorizedCaller(stakerAddr, store.ReadOnly); err != nil {
		panic(err)
	}

	if err := kvStore.AddAuthorizedCaller(dustConverterAddr, store.ReadOnly); err != nil {
		panic(err)
	}
}

func initializeDomainStore(kvStore store.KVStore) any {
	return NewPoolStore(kvStore)
}

// getImplementation returns the currently active pool implementation.
// This function is used by all proxy functions to route calls to the active implementation.
// If no implementation is set, it panics to prevent invalid state.
func getImplementation() IPool {
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

	impl, ok := result.(IPool)
	if !ok {
		return errors.New("impl is not an IPool")
	}

	implementation = impl

	return nil
}
