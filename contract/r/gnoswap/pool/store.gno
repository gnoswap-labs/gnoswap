package pool

import (
	"errors"

	"gno.land/p/gnoswap/store/v1"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// StoreKey defines the keys used for storing pool data in the KV store.
// These keys are prefixed with the domain address to ensure namespace isolation.
type StoreKey string

// Returns:
//   - keyText: the textual store key represented by s.
func (s StoreKey) String() string {
	return string(s)
}

const (
	// Pool data storage keys
	StoreKeyPools                StoreKey = "pools"                // Map containing all pools
	StoreKeyObservations         StoreKey = "observations"         // poolPath -> observation B+tree
	StoreKeyFeeAmountTickSpacing StoreKey = "feeAmountTickSpacing" // Fee tier to tick spacing mapping
	StoreKeySlot0FeeProtocol     StoreKey = "slot0FeeProtocol"     // Protocol fee denominator(s)

	// Protocol fee storage keys
	StoreKeyPoolCreationFee     StoreKey = "poolCreationFee"     // Pool creation fee amount
	StoreKeyPendingProtocolFees StoreKey = "pendingProtocolFees" // tokenPath -> amount held locally for protocol_fee
	StoreKeyWithdrawalFeeBPS    StoreKey = "withdrawalFeeBPS"    // Withdrawal fee in basis points
	StoreKeyUnlocked            StoreKey = "unlocked"            // Global pool reentrancy lock

	// Swap hook storage keys
	StoreKeySwapStartHook StoreKey = "swapStartHook" // Swap start hook function
	StoreKeySwapEndHook   StoreKey = "swapEndHook"   // Swap end hook function
	StoreKeyTickCrossHook StoreKey = "tickCrossHook" // Tick cross hook function
)

// poolStore implements the IPoolStore interface for pool domain storage.
// It provides type-safe access to pool data stored in the underlying KV store.
type poolStore struct {
	kvStore store.KVStore
}

// Returns:
//   - exists: true when the pool collection key is present in the KV store.
func (s *poolStore) HasPools() bool {
	return s.kvStore.Has(StoreKeyPools.String())
}

// GetPools retrieves the map containing all pool data.
// This is the main data structure that stores all pool instances.
// Returns:
//   - pools: the B+tree containing all persisted pool instances; panics if the
//     KV store cannot read it or the stored value is nil.
func (s *poolStore) GetPools() *bptree.BPTree {
	pools, err := s.kvStore.GetBPTree(StoreKeyPools.String())
	if err != nil {
		panic(err)
	}

	if pools == nil {
		panic("pools is nil")
	}

	return pools
}

// SetPools stores the map containing all pool data.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - pools: non-nil B+tree containing the pool instances to persist.
//
// Returns:
//   - err: nil when the pool tree is stored; ErrSpoofedRealm for a non-current
//     realm, or the underlying KV-store write error.
func (s *poolStore) SetPools(_ int, rlm realm, pools *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if pools == nil {
		panic("pools is nil")
	}

	return s.kvStore.Set(0, rlm, StoreKeyPools.String(), pools)
}

// Returns:
//   - exists: true when the observations collection key is present in the KV store.
func (s *poolStore) HasObservations() bool {
	return s.kvStore.Has(StoreKeyObservations.String())
}

// Returns:
//   - observations: the B+tree containing persisted observation trees; panics if
//     the KV store cannot read it or the stored value is nil.
func (s *poolStore) GetObservations() *bptree.BPTree {
	observations, err := s.kvStore.GetBPTree(StoreKeyObservations.String())
	if err != nil {
		panic(err)
	}
	if observations == nil {
		panic("observations is nil")
	}
	return observations
}

// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - observations: non-nil B+tree containing the observation data to persist.
//
// Returns:
//   - err: nil when the observation tree is stored; ErrSpoofedRealm for a
//     non-current realm, or the underlying KV-store write error.
func (s *poolStore) SetObservations(_ int, rlm realm, observations *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}
	if observations == nil {
		panic("observations is nil")
	}
	return s.kvStore.Set(0, rlm, StoreKeyObservations.String(), observations)
}

// Returns:
//   - exists: true when the fee-tier/tick-spacing mapping key is present in the
//     KV store.
func (s *poolStore) HasFeeAmountTickSpacing() bool {
	return s.kvStore.Has(StoreKeyFeeAmountTickSpacing.String())
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
// Returns:
//   - feeAmountTickSpacing: a copy of the fee amount to tick-spacing mapping;
//     panics if the KV value cannot be read, has the wrong type, or is nil.
func (s *poolStore) GetFeeAmountTickSpacing() map[uint32]int32 {
	result, err := s.kvStore.Get(StoreKeyFeeAmountTickSpacing.String())
	if err != nil {
		panic(err)
	}

	feeAmountTickSpacing, ok := result.(map[uint32]int32)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to map[uint32]int32: %T", result))
	}

	if feeAmountTickSpacing == nil {
		panic("feeAmountTickSpacing is nil")
	}

	return cloneFeeAmountTickSpacings(feeAmountTickSpacing)
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - feeAmountTickSpacing: non-nil mapping from fee tiers to their required
//     int32 tick spacing values.
//
// Returns:
//   - err: nil when the mapping is stored; ErrSpoofedRealm for a non-current
//     realm, or the underlying KV-store write error.
func (s *poolStore) SetFeeAmountTickSpacing(_ int, rlm realm, feeAmountTickSpacing map[uint32]int32) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if feeAmountTickSpacing == nil {
		panic("feeAmountTickSpacing is nil")
	}

	return s.kvStore.Set(0, rlm, StoreKeyFeeAmountTickSpacing.String(), feeAmountTickSpacing)
}

// Returns:
//   - exists: true when the slot0 protocol-fee configuration key is present in
//     the KV store.
func (s *poolStore) HasSlot0FeeProtocol() bool {
	return s.kvStore.Has(StoreKeySlot0FeeProtocol.String())
}

// GetSlot0FeeProtocol retrieves the protocol fee denominator(s) for slot0.
// Returns:
//   - slot0FeeProtocol: packed protocol-fee denominator configuration for
//     slot0; panics if the KV value cannot be read or has the wrong type.
func (s *poolStore) GetSlot0FeeProtocol() uint8 {
	result, err := s.kvStore.Get(StoreKeySlot0FeeProtocol.String())
	if err != nil {
		panic(err)
	}

	slot0FeeProtocol, ok := result.(uint8)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint8: %T", result))
	}

	return slot0FeeProtocol
}

// SetSlot0FeeProtocol stores the protocol fee denominator(s) for slot0.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - slot0FeeProtocol: packed uint8 protocol-fee denominators for token0 and
//     token1.
//
// Returns:
//   - err: nil when the protocol-fee configuration is stored; ErrSpoofedRealm
//     for a non-current realm, or the underlying KV-store write error.
func (s *poolStore) SetSlot0FeeProtocol(_ int, rlm realm, slot0FeeProtocol uint8) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeySlot0FeeProtocol.String(), slot0FeeProtocol)
}

// Returns:
//   - exists: true when the pool-creation-fee key is present in the KV store.
func (s *poolStore) HasPoolCreationFee() bool {
	return s.kvStore.Has(StoreKeyPoolCreationFee.String())
}

// GetPoolCreationFee retrieves the pool creation fee amount.
// Returns:
//   - poolCreationFee: configured pool-creation charge in the chain's smallest
//     currency unit; panics if the KV value cannot be read or has the wrong type.
func (s *poolStore) GetPoolCreationFee() int64 {
	result, err := s.kvStore.Get(StoreKeyPoolCreationFee.String())
	if err != nil {
		panic(err)
	}

	poolCreationFee, ok := result.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to int64: %T", result))
	}

	return poolCreationFee
}

// SetPoolCreationFee stores the pool creation fee amount.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - poolCreationFee: pool-creation charge in the chain's smallest currency
//     unit.
//
// Returns:
//   - err: nil when the fee is stored; ErrSpoofedRealm for a non-current realm,
//     or the underlying KV-store write error.
func (s *poolStore) SetPoolCreationFee(_ int, rlm realm, poolCreationFee int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPoolCreationFee.String(), poolCreationFee)
}

// Returns:
//   - exists: true when the pending protocol-fees key is present in the KV store.
func (s *poolStore) HasPendingProtocolFees() bool {
	return s.kvStore.Has(StoreKeyPendingProtocolFees.String())
}

// Returns:
//   - pendingProtocolFees: mapping from token path to pending protocol-fee
//     amount in the chain's smallest currency unit; panics if the KV value
//     cannot be read or has the wrong type.
func (s *poolStore) GetPendingProtocolFees() map[string]int64 {
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

// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - pendingProtocolFees: token-path-to-amount mapping; amounts are in the
//     chain's smallest currency unit and are copied before storage.
//
// Returns:
//   - err: nil when the copied mapping is stored; ErrSpoofedRealm for a
//     non-current realm, or the underlying KV-store write error.
func (s *poolStore) SetPendingProtocolFees(_ int, rlm realm, pendingProtocolFees map[string]int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	// The map is copied here so it is allocated by, and therefore mutable from, this realm.
	owned := make(map[string]int64, len(pendingProtocolFees))
	for tokenPath, amount := range pendingProtocolFees {
		owned[tokenPath] = amount
	}

	return s.kvStore.Set(0, rlm, StoreKeyPendingProtocolFees.String(), owned)
}

// Parameters:
//   - tokenPath: token contract path used as the pending-fee map key.
//
// Returns:
//   - amount: pending protocol-fee amount for tokenPath in the chain's smallest
//     currency unit, or zero when no entry exists.
func (s *poolStore) GetPendingProtocolFee(tokenPath string) int64 {
	return s.GetPendingProtocolFees()[tokenPath]
}

// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - tokenPath: token contract path identifying the pending-fee entry.
//   - amount: pending protocol-fee amount to assign for tokenPath, in the
//     chain's smallest currency unit.
//
// Returns:
//   - err: nil after the map entry is updated; ErrSpoofedRealm for a non-current
//     realm, or store.ErrWritePermissionDenied for an unauthorized code realm.
func (s *poolStore) SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if rlm.IsCode() && !s.kvStore.IsWriteAuthorized(rlm.Address()) {
		return errors.New(store.ErrWritePermissionDenied)
	}

	s.GetPendingProtocolFees()[tokenPath] = amount

	return nil
}

// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - tokenPath: token contract path identifying the pending-fee entry to delete.
//
// Returns:
//   - err: nil after the map entry is removed; ErrSpoofedRealm for a non-current
//     realm, or store.ErrWritePermissionDenied for an unauthorized code realm.
func (s *poolStore) RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if rlm.IsCode() && !s.kvStore.IsWriteAuthorized(rlm.Address()) {
		return errors.New(store.ErrWritePermissionDenied)
	}

	delete(s.GetPendingProtocolFees(), tokenPath)

	return nil
}

// Returns:
//   - exists: true when the withdrawal-fee key is present in the KV store.
func (s *poolStore) HasWithdrawalFeeBPS() bool {
	return s.kvStore.Has(StoreKeyWithdrawalFeeBPS.String())
}

// GetWithdrawalFeeBPS retrieves the withdrawal fee in basis points.
// Returns:
//   - withdrawalFeeBPS: withdrawal fee expressed in basis points (1/100 of a
//     percent); panics if the KV value cannot be read or has the wrong type.
func (s *poolStore) GetWithdrawalFeeBPS() uint64 {
	result, err := s.kvStore.Get(StoreKeyWithdrawalFeeBPS.String())
	if err != nil {
		panic(err)
	}

	withdrawalFeeBPS, ok := result.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
	}

	return withdrawalFeeBPS
}

// SetWithdrawalFeeBPS stores the withdrawal fee in basis points.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - withdrawalFeeBPS: withdrawal fee in basis points, where 100 basis points
//     equals one percent.
//
// Returns:
//   - err: nil when the fee is stored; ErrSpoofedRealm for a non-current realm,
//     or the underlying KV-store write error.
func (s *poolStore) SetWithdrawalFeeBPS(_ int, rlm realm, withdrawalFeeBPS uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyWithdrawalFeeBPS.String(), withdrawalFeeBPS)
}

// Returns:
//   - exists: true when the global unlocked-state key is present in the KV store.
func (s *poolStore) HasUnlocked() bool {
	return s.kvStore.Has(StoreKeyUnlocked.String())
}

// Returns:
//   - unlocked: the persisted global reentrancy-lock state; panics if the KV
//     value cannot be read or has the wrong type.
func (s *poolStore) GetUnlocked() bool {
	result, err := s.kvStore.Get(StoreKeyUnlocked.String())
	if err != nil {
		panic(err)
	}

	unlocked, ok := result.(bool)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to bool: %T", result))
	}

	return unlocked
}

// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - unlocked: true when pool operations may proceed without the global lock.
//
// Returns:
//   - err: nil when the lock state is stored; ErrSpoofedRealm for a non-current
//     realm, or the underlying KV-store write error.
func (s *poolStore) SetUnlocked(_ int, rlm realm, unlocked bool) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyUnlocked.String(), unlocked)
}

// HasSwapStartHook checks if the swap start hook is set.
// Returns:
//   - exists: true when a swap-start hook key is present in the KV store.
func (s *poolStore) HasSwapStartHook() bool {
	return s.kvStore.Has(StoreKeySwapStartHook.String())
}

// GetSwapStartHook retrieves the swap start hook function.
// Returns:
//   - swapStartHook: stored callback invoked at swap start with the current
//     realm, pool path, and block timestamp; panics if the KV value cannot be
//     read or has the wrong function type.
func (s *poolStore) GetSwapStartHook() func(cur realm, poolPath string, timestamp int64) {
	result, err := s.kvStore.Get(StoreKeySwapStartHook.String())
	if err != nil {
		panic(err)
	}

	swapStartHook, ok := result.(func(cur realm, poolPath string, timestamp int64))
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func(poolPath string, timestamp int64): %T", result))
	}

	return swapStartHook
}

// SetSwapStartHook stores the swap start hook function.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - swapStartHook: callback receiving the current realm, pool path, and
//     block timestamp when a swap starts.
//
// Returns:
//   - err: nil when the callback is stored; ErrSpoofedRealm for a non-current
//     realm, or the underlying KV-store write error.
func (s *poolStore) SetSwapStartHook(_ int, rlm realm, swapStartHook func(cur realm, poolPath string, timestamp int64)) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeySwapStartHook.String(), swapStartHook)
}

// HasSwapEndHook checks if the swap end hook is set.
// Returns:
//   - exists: true when a swap-end hook key is present in the KV store.
func (s *poolStore) HasSwapEndHook() bool {
	return s.kvStore.Has(StoreKeySwapEndHook.String())
}

// GetSwapEndHook retrieves the swap end hook function.
// Returns:
//   - swapEndHook: stored callback receiving the current realm and pool path at
//     swap end and returning an error; panics if the KV value cannot be read or
//     has the wrong function type.
func (s *poolStore) GetSwapEndHook() func(cur realm, poolPath string) error {
	result, err := s.kvStore.Get(StoreKeySwapEndHook.String())
	if err != nil {
		panic(err)
	}

	swapEndHook, ok := result.(func(cur realm, poolPath string) error)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func(poolPath string): %T", result))
	}

	return swapEndHook
}

// SetSwapEndHook stores the swap end hook function.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - swapEndHook: callback receiving the current realm and pool path at swap
//     end and returning any hook error.
//
// Returns:
//   - err: nil when the callback is stored; ErrSpoofedRealm for a non-current
//     realm, or the underlying KV-store write error.
func (s *poolStore) SetSwapEndHook(_ int, rlm realm, swapEndHook func(cur realm, poolPath string) error) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeySwapEndHook.String(), swapEndHook)
}

// HasTickCrossHook checks if the tick cross hook is set.
// Returns:
//   - exists: true when a tick-cross hook key is present in the KV store.
func (s *poolStore) HasTickCrossHook() bool {
	return s.kvStore.Has(StoreKeyTickCrossHook.String())
}

// GetTickCrossHook retrieves the tick cross hook function.
// Returns:
//   - tickCrossHook: stored callback receiving the current realm, pool path,
//     crossed tick, swap direction, and block timestamp; panics if the KV value
//     cannot be read or has the wrong function type.
func (s *poolStore) GetTickCrossHook() func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	result, err := s.kvStore.Get(StoreKeyTickCrossHook.String())
	if err != nil {
		panic(err)
	}

	tickCrossHook, ok := result.(func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64))
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to func(poolPath string, tickId int32, zeroForOne bool, timestamp int64): %T", result))
	}

	return tickCrossHook
}

// SetTickCrossHook stores the tick cross hook function.
// Parameters:
//   - _: leading realm-call discriminator; callers pass 0.
//   - rlm: propagated realm context; it must be the current realm or the method
//     returns ErrSpoofedRealm before writing.
//   - tickCrossHook: callback receiving the current realm, pool path, crossed
//     tick ID, swap direction, and block timestamp.
//
// Returns:
//   - err: nil when the callback is stored; ErrSpoofedRealm for a non-current
//     realm, or the underlying KV-store write error.
func (s *poolStore) SetTickCrossHook(_ int, rlm realm, tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyTickCrossHook.String(), tickCrossHook)
}

// NewPoolStore creates a new pool store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
// Parameters:
//   - kvStore: KV store used to persist and retrieve pool-domain state.
//
// Returns:
//   - poolStore: an IPoolStore implementation backed by kvStore.
func NewPoolStore(kvStore store.KVStore) IPoolStore {
	return &poolStore{
		kvStore: kvStore,
	}
}
