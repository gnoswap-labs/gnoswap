package dca_order

import (
	"errors"

	_ "gno.land/r/gnoswap/rbac/v1" // initialize readable contract role(s)

	"gno.land/p/gnoswap/store/v1"
	"gno.land/p/gnoswap/version_manager/v1"
)

var (
	currentAddress address
	kvStore        store.KVStore

	versionManager version_manager.VersionManager
	implementation IDCAOrder
)

func init(cur realm) {
	currentAddress = cur.Address()
	kvStore = store.NewKVStore(currentAddress)

	versionManager = version_manager.NewVersionManager(
		cur.PkgPath(),
		kvStore,
		initializeDomainStore,
	)

	implementation = nil
}

func initializeDomainStore(_ int, rlm realm, kvStore store.KVStore) any {
	return NewDCAOrderStore(kvStore)
}

// Address returns the dca_order realm address, which escrows order funds.
// Users approve this address before CreateOrder.
func Address() address {
	return currentAddress
}

func getImplementation() IDCAOrder {
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

	impl, ok := result.(IDCAOrder)
	if !ok {
		return errors.New("impl is not an IDCAOrder")
	}

	implementation = impl

	return nil
}
