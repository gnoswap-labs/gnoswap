package staker

import (
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	"gno.land/r/gnoswap/access"
)

var (
	ErrSpoofedRealm = errors.New("rlm does not match the current crossing frame")

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IStaker
)

func init(cur realm) {
	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(cur.Address())
	initRegisterWritableContract(cur)

	// Initialize the initializers map to store implementation registration functions
	versionManager = version_manager.NewVersionManager(
		cur.PkgPath(),
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

func initRegisterWritableContract(cur realm) {
	poolAddr := access.MustGetAddress(prbac.ROLE_POOL.String())

	if err := kvStore.AddAuthorizedCaller(0, cur, poolAddr, store.Write); err != nil {
		panic(err)
	}
}

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
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
