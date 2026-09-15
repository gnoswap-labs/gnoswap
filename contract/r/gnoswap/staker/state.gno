package staker

import (
	"errors"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"

	"gno.land/r/gnoswap/access"
)

const ErrSpoofedRealm = "rlm does not match the current crossing frame"

var (
	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IStaker
)

// init initializes the staker realm's persistent store, writable-caller registration, and version manager.
//
// Parameters:
//   - cur: Runtime-supplied current realm context used to create and authorize this realm's stores.
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

// initRegisterWritableContract registers the pool realm as an authorized KV-store writer.
//
// Parameters:
//   - cur: Current staker realm context propagated to the authorization update.
func initRegisterWritableContract(cur realm) {
	poolAddr := access.MustGetAddress(prbac.ROLE_POOL.String())

	if err := kvStore.AddAuthorizedCaller(0, cur, poolAddr, store.Write); err != nil {
		panic(err)
	}
}

// initializeDomainStore constructs the implementation-specific staker store for the version manager.
//
// Parameters:
//   - _: Internal crossing discriminator forwarded as 0 by the version manager.
//   - rlm: Current realm context forwarded by the version manager; this initializer does not inspect it.
//   - kvStore: Persistent key/value store backing the new staker store.
//
// Returns:
//   - store: Newly constructed StakerStore returned as an any value for version-manager registration.
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewStakerStore(kvStore)
}

// getImplementation returns the currently selected staker implementation.
//
// Returns:
//   - implementation: Registered IStaker implementation; panics if updateImplementation has not initialized one.
func getImplementation() IStaker {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation loads and records the version manager's current implementation.
//
// Returns:
//   - err: Non-nil when no implementation is registered or the current value is not an IStaker; nil after the global implementation is updated.
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
