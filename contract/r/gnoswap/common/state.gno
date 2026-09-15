package common

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store/v1"
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
