package common

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	currentAddress address
	domainPath     string

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation ICommon
)

// init initializes the common realm's address, domain path, key-value store,
// version manager, and unset implementation.
//
// Parameters:
//   - cur: initialization realm supplied by the Gno runtime
func init(cur realm) {
	currentAddress = cur.Address()
	domainPath = cur.PkgPath()

	kvStore = store.NewKVStore(currentAddress)

	versionManager = version_manager.NewVersionManager(
		domainPath,
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

// common keeps no domain state; implementations only resolve tokens.
//
// Parameters:
//   - _: version-manager discriminator; callers pass 0
//   - rlm: propagated realm context supplied to the initializer callback
//   - kvStore: domain key-value store supplied by the version manager; this
//     common package does not persist additional domain state in it
//
// Returns:
//   - state: nil because common has no implementation-specific domain state
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return nil
}

// getImplementation returns the registered current implementation.
//
// Returns:
//   - implementation: current ICommon implementation; panics if none has been initialized
func getImplementation() ICommon {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation loads the version manager's current implementation and
// stores it as the active ICommon implementation.
//
// Returns:
//   - error: nil when the current implementation is present and implements
//     ICommon; an error when it is absent or has the wrong type
func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(ICommon)
	if !ok {
		return errors.New("impl is not an ICommon")
	}

	implementation = impl

	return nil
}
