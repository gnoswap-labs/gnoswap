package router

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeySwapFee StoreKey = "swapFee" // Swap fee in basis points
)

type routerStore struct {
	kvStore store.KVStore
}

func (s *routerStore) HasSwapFeeKey() bool {
	return s.kvStore.Has(StoreKeySwapFee.String())
}

// GetSwapFee retrieves the current swap fee.
// If not set, returns the default swap fee.
func (s *routerStore) GetSwapFee() uint64 {
	result, err := s.kvStore.Get(StoreKeySwapFee.String())
	if err != nil {
		panic(err)
	}

	swapFee, ok := result.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
	}

	return swapFee
}

// SetSwapFee stores the swap fee.
func (s *routerStore) SetSwapFee(fee uint64) error {
	return s.kvStore.Set(StoreKeySwapFee.String(), fee)
}

// NewRouterStore creates a new router store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewRouterStore(kvStore store.KVStore) IRouterStore {
	rs := &routerStore{
		kvStore: kvStore,
	}

	return rs
}
