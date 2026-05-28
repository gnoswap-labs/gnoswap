package governance

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	// Package-init reads use chain/runtime/unsafe.CurrentRealm because there
	// is no `cur realm` in scope at package-initialization time. The values
	// captured here describe the governance realm itself, not any caller.
	currentAddress address
	domainPath     string

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IGovernance
)

func init(cur realm) {
	currentAddress = cur.Address()
	domainPath = cur.PkgPath()

	kvStore = store.NewKVStore(currentAddress)
	versionManager = version_manager.NewVersionManager(domainPath, kvStore, initializeDomainStore)

	implementation = nil
}

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewGovernanceStore(kvStore)
}

func getImplementation() IGovernance {
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

	impl, ok := result.(IGovernance)
	if !ok {
		return errors.New("impl is not an IGovernance")
	}

	implementation = impl

	return nil
}
