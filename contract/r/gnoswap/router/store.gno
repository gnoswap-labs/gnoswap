package router

import (
	"errors"

	"gno.land/p/gnoswap/store"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const errSpoofedRealm = "rlm does not match the current crossing frame"

type StoreKey string

// String converts the typed store key to the string key used by KVStore.
//
// Returns:
//   - key: underlying string representation of the store key
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

// HasSwapFeeKey reports whether persistent storage contains the router swap-fee key.
//
// Returns:
//   - exists: true when the swap-fee key is present, otherwise false
func (s *routerStore) HasSwapFeeKey() bool {
	return s.kvStore.Has(StoreKeySwapFee.String())
}

// GetSwapFee retrieves the current swap fee from persistent storage.
//
// Returns:
//   - fee: configured router fee in basis points; panics if the key is missing or has the wrong type
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

// SetSwapFee stores the router fee in persistent storage.
//
// Parameters:
//   - _: leading call discriminator; callers pass 0
//   - rlm: current realm context; must be the current crossing frame
//   - fee: router fee rate in basis points
//
// Returns:
//   - err: nil when storage succeeds; an error when rlm is not current or KVStore rejects the write
func (s *routerStore) SetSwapFee(_ int, rlm realm, fee uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(errSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeySwapFee.String(), fee)
}

// HasPendingProtocolFeesKey reports whether persistent storage contains the pending-fees map.
//
// Returns:
//   - exists: true when the pending protocol-fees key is present, otherwise false
func (s *routerStore) HasPendingProtocolFeesKey() bool {
	return s.kvStore.Has(StoreKeyPendingProtocolFees.String())
}

// GetPendingProtocolFees retrieves the token-path keyed pending protocol-fees map.
//
// Returns:
//   - fees: stored token-path to pending amount map; panics if storage is missing or has the wrong type
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

// SetPendingProtocolFees replaces the pending protocol-fees map in persistent storage.
//
// Parameters:
//   - _: leading call discriminator; callers pass 0
//   - rlm: current realm context; must be the current crossing frame
//   - fees: token-path keyed pending fee amounts to store; entries are copied into realm-owned storage
//
// Returns:
//   - err: nil when storage succeeds; an error when rlm is not current or KVStore rejects the write
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

// GetPendingProtocolFee returns the pending amount recorded for one token path.
//
// Parameters:
//   - tokenPath: token contract path whose pending protocol fee is queried
//
// Returns:
//   - amount: pending fee amount for tokenPath, or zero when no entry exists
func (s *routerStore) GetPendingProtocolFee(tokenPath string) int64 {
	return s.GetPendingProtocolFees()[tokenPath]
}

// SetPendingProtocolFee updates one token path's pending protocol-fee amount.
//
// Parameters:
//   - _: leading call discriminator; callers pass 0
//   - rlm: current realm context; must be current and authorized to write storage
//   - tokenPath: token contract path whose pending amount is updated
//   - amount: pending protocol-fee amount to record
//
// Returns:
//   - err: nil when updated; an error when the realm is spoofed or lacks KVStore write permission
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

// RemovePendingProtocolFee deletes one token path's pending protocol-fee entry.
//
// Parameters:
//   - _: leading call discriminator; callers pass 0
//   - rlm: current realm context; must be current and authorized to write storage
//   - tokenPath: token contract path whose pending amount is removed
//
// Returns:
//   - err: nil when removed; an error when the realm is spoofed or lacks KVStore write permission
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

// NewRouterStore creates a router store backed by the provided KV store.
//
// Parameters:
//   - kvStore: persistent key-value store used for router fee and pending-fee data
//
// Returns:
//   - routerStore: router storage implementation using kvStore
func NewRouterStore(kvStore store.KVStore) IRouterStore {
	rs := &routerStore{
		kvStore: kvStore,
	}

	return rs
}
