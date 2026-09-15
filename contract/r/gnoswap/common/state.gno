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

func getImplementation() ICommon {
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

	impl, ok := result.(ICommon)
	if !ok {
		return errors.New("impl is not an ICommon")
	}

	implementation = impl

	return nil
}
