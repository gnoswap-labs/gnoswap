package governance

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

var (
	// currentAddress and domainPath describe the governance realm itself.
	// They are captured from the `cur realm` parameter in init(cur realm),
	// which resolves to this governance domain realm.
	currentAddress address
	domainPath     string

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IGovernance

	// ErrSpoofedRealm is returned/panicked when a captured realm token no
	// longer matches the live crossing frame (rlm.IsCurrent() == false).
	ErrSpoofedRealm = errors.New("rlm does not match the current crossing frame")
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
