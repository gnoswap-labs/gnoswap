package limit_order

import (
	"strings"

	"gno.land/p/gnoswap/store/v1"
	bptree "gno.land/p/nt/bptree/v0"

	"gno.land/r/gnoswap/access/v1"
)

var (
	currentAddress address
	domainPath     string

	kvStore store.KVStore
	loStore ILimitOrderStore

	implementation ILimitOrder
)

func init(cur realm) {
	currentAddress = cur.Address()
	domainPath = cur.PkgPath()

	kvStore = store.NewKVStore(currentAddress)
	loStore = NewLimitOrderStore(kvStore)
	if err := loStore.SetLocked(0, cur, false); err != nil {
		panic(err)
	}

	if !loStore.HasOrdersStoreKey() {
		if err := loStore.SetOrders(0, cur, bptree.NewBPTreeN(16)); err != nil {
			panic(err)
		}
	}

	if !loStore.HasOrderNextIDStoreKey() {
		if err := loStore.SetOrderNextID(0, cur, 1); err != nil {
			panic(err)
		}
	}

	if !loStore.HasOrdersByOwnerStoreKey() {
		if err := loStore.SetOrdersByOwner(0, cur, bptree.NewBPTreeN(16)); err != nil {
			panic(err)
		}
	}

	implementation = nil
}

// Address returns the address of the limit order contract
func Address() address {
	return currentAddress
}

// GetStore returns the limit order store to a version implementation.
func GetStore(cur realm) ILimitOrderStore {
	assertImplementationRealm(cur)
	return loStore
}

// GetContractAddress returns the address of the limit order contract.
func GetContractAddress() address {
	return currentAddress
}

func getImplementation() ILimitOrder {
	if implementation == nil {
		panic("implementation is not initialized")
	}
	return implementation
}

func assertImplementationRealm(cur realm) {
	access.AssertIsRlmCurrent(0, cur)
	if previous := cur.Previous(); previous.IsUser() || !strings.HasPrefix(previous.PkgPath(), domainPath+"/") {
		panic("limit_order: caller is not an implementation realm")
	}
}

// RegisterImplementation registers an implementation from a version realm.
func RegisterImplementation(cur realm, impl ILimitOrder) {
	assertImplementationRealm(cur)
	if implementation != nil {
		panic("implementation already registered")
	}
	implementation = impl
}
