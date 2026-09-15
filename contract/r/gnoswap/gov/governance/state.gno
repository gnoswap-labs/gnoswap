package governance

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/version_manager"
)

const ErrSpoofedRealm = "rlm does not match the current crossing frame"

var (
	// currentAddress and domainPath describe the governance realm itself.
	// They are captured from the `cur realm` parameter in init(cur realm),
	// which resolves to this governance domain realm.
	currentAddress address
	domainPath     string

	kvStore store.KVStore

	versionManager version_manager.VersionManager
	implementation IGovernance
)

// init captures the governance realm identity and initializes versioned storage.
//
// Parameters:
//   - cur: realm supplied by the runtime for this governance domain
func init(cur realm) {
	currentAddress = cur.Address()
	domainPath = cur.PkgPath()

	kvStore = store.NewKVStore(currentAddress)
	versionManager = version_manager.NewVersionManager(domainPath, kvStore, initializeDomainStore)

	implementation = nil
}

// initializeDomainStore creates the governance store used by a version manager.
//
// Parameters:
//   - _: Noncrossing initialization-callback discriminator; pass 0.
//   - rlm: propagated realm context associated with the store initialization callback
//   - kvStore: key-value store bound to this governance domain
//
// Returns:
//   - any: newly created governance store value
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewGovernanceStore(kvStore)
}

// getImplementation returns the currently selected governance implementation.
//
// Returns:
//   - IGovernance: active governance implementation; panics if initialization has not selected one
func getImplementation() IGovernance {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation loads and installs the current versioned governance implementation.
//
// Returns:
//   - error: nil when the implementation is installed, or an error when no current implementation exists or its type is invalid
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
