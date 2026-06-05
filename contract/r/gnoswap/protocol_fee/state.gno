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

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewProtocolFeeStore(kvStore)
}

func getImplementation() IProtocolFee {
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

	impl, ok := result.(IProtocolFee)
	if !ok {
		return errors.New("impl is not an IProtocolFee")
	}

	implementation = impl

	return nil
}
