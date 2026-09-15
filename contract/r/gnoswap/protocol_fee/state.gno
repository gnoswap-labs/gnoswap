package protocol_fee

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
	implementation IProtocolFee
)

// init initializes this realm's address, package path, KV store, and version manager.
//
// Parameters:
//   - cur: Current realm context supplied by the runtime; its address and package path identify this protocol-fee domain.
func init(cur realm) {
	currentAddress = cur.Address()
	domainPath = cur.PkgPath()

	// Create a new KV store instance for this domain
	kvStore = store.NewKVStore(currentAddress)

	// Initialize the initializers map to store implementation registration functions
	versionManager = version_manager.NewVersionManager(
		domainPath,
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

// initializeDomainStore constructs the protocol-fee store used by the version manager.
//
// Parameters:
//   - _: Version-manager callback discriminator; pass 0.
//   - rlm: Propagated realm context supplied by the version manager; this constructor does not validate it.
//   - kvStore: Domain KV store that the returned protocol-fee store must use.
//
// Returns:
//   - store: A protocol-fee store wrapper backed by kvStore.
func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewProtocolFeeStore(kvStore)
}

// getImplementation returns the currently selected protocol-fee implementation.
//
// Returns:
//   - implementation: The active IProtocolFee implementation; the function panics until an implementation has been selected.
func getImplementation() IProtocolFee {
	if implementation == nil {
		panic("implementation is not initialized")
	}

	return implementation
}

// updateImplementation loads and records the version manager's current protocol-fee implementation.
//
// Returns:
//   - err: Nil after implementation is updated; an error when no current implementation exists or the value is not an IProtocolFee.
func updateImplementation() error {
	result := versionManager.GetCurrentImplementation()
	if result == nil {
		return errors.New("implementation is not initialized")
	}

	impl, ok := result.(IProtocolFee)
	if !ok {
		return errors.New("impl is not an IProtocolFee")
	}

	implementation = impl

	return nil
}
