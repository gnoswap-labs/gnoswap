package limit_order

import (
	"chain/runtime"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
)

var (
	currentAddress = runtime.CurrentRealm().Address()
	domainPath     = runtime.CurrentRealm().PkgPath()

	kvStore store.KVStore
	loStore ILimitOrderStore

	implementation ILimitOrder
)

func init() {
	kvStore = store.NewKVStore(currentAddress)
	loStore = NewLimitOrderStore(kvStore)

	// Initialize store keys
	if !loStore.HasOrdersStoreKey() {
		loStore.SetOrders(avl.NewTree())
	}

	if !loStore.HasOrderNextIDStoreKey() {
		loStore.SetOrderNextID(1)
	}

	if !loStore.HasOrdersByOwnerStoreKey() {
		loStore.SetOrdersByOwner(avl.NewTree())
	}

	implementation = nil
}

// Address returns the address of the limit order contract
func Address() address {
	return currentAddress
}

// GetStore returns the limit order store (for v1 implementation)
func GetStore() ILimitOrderStore {
	return loStore
}

// GetContractAddress returns the contract address (for v1 implementation)
func GetContractAddress() address {
	return currentAddress
}

func getImplementation() ILimitOrder {
	if implementation == nil {
		panic("implementation is not initialized")
	}
	return implementation
}

// RegisterImplementation registers an implementation
// Called by v1/init.gno
func RegisterImplementation(cur realm, impl ILimitOrder) {
	if implementation != nil {
		panic("implementation already registered")
	}
	implementation = impl
}
