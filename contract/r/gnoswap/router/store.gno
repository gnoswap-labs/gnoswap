package router

import (
	"errors"

	"gno.land/p/gnoswap/store/v1"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const errSpoofedRealm = "rlm does not match the current crossing frame"

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
		return errors.New(errSpoofedRealm)
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
		return errors.New(errSpoofedRealm)
	}

	// The map is copied here so it is allocated by, and therefore mutable from, this realm.
	owned := make(map[string]int64, len(fees))
	for tokenPath, amount := range fees {
		owned[tokenPath] = amount
	}

	return s.kvStore.Set(0, rlm, StoreKeyPendingProtocolFees.String(), owned)
}

func (s *routerStore) GetPendingProtocolFee(tokenPath string) int64 {
	return s.GetPendingProtocolFees()[tokenPath]
}

func (s *routerStore) SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	if rlm.IsCode() && !s.kvStore.IsWriteAuthorized(rlm.Address()) {
		return errors.New(store.ErrWritePermissionDenied)
	}

	s.GetPendingProtocolFees()[tokenPath] = amount

	return nil
}

func (s *routerStore) RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	if rlm.IsCode() && !s.kvStore.IsWriteAuthorized(rlm.Address()) {
		return errors.New(store.ErrWritePermissionDenied)
	}

	delete(s.GetPendingProtocolFees(), tokenPath)

	return nil
}

// NewRouterStore creates a new router store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewRouterStore(kvStore store.KVStore) IRouterStore {
	rs := &routerStore{
		kvStore: kvStore,
	}

	return rs
}
