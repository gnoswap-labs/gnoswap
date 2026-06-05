package router

import (
	"errors"

	"gno.land/p/gnoswap/store"
	ufmt "gno.land/p/nt/ufmt/v0"
)

var errSpoofedRealm = errors.New("rlm does not match the current crossing frame")

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeySwapFee             StoreKey = "swapFee"             // Swap fee in basis points
	StoreKeyPendingProtocolFees StoreKey = "pendingProtocolFees" // tokenPath -> amount held locally for protocol_fee
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
func (s *routerStore) SetSwapFee(_ int, rlm realm, fee uint64) error {
	if !rlm.IsCurrent() {
		return errSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeySwapFee.String(), fee)
}

func (s *routerStore) HasPendingProtocolFeesKey() bool {
	return s.kvStore.Has(StoreKeyPendingProtocolFees.String())
}

func (s *routerStore) GetPendingProtocolFees() map[string]int64 {
	result, err := s.kvStore.Get(StoreKeyPendingProtocolFees.String())
	if err != nil {
		panic(err)
	}

	pendingProtocolFees, ok := result.(map[string]int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to map[string]int64: %T", result))
	}

	return pendingProtocolFees
}

func (s *routerStore) SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error {
	if !rlm.IsCurrent() {
		return errSpoofedRealm
	}

	return s.kvStore.Set(0, rlm, StoreKeyPendingProtocolFees.String(), fees)
}

// NewRouterStore creates a new router store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewRouterStore(kvStore store.KVStore) IRouterStore {
	rs := &routerStore{
		kvStore: kvStore,
	}

	return rs
}
