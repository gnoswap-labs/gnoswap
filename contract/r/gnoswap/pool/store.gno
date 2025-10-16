package pool

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// StoreKey defines the keys used for storing pool data in the KV store.
// These keys are prefixed with the domain address to ensure namespace isolation.
type StoreKey string

const (
	// Pool data storage keys
	StoreKeyPools                StoreKey = "pools"                // AVL tree containing all pools
	StoreKeyFeeAmountTickSpacing StoreKey = "feeAmountTickSpacing" // Fee tier to tick spacing mapping
	StoreKeySlot0FeeProtocol     StoreKey = "slot0FeeProtocol"     // Protocol fee percentage

	// Protocol fee storage keys
	StoreKeyPoolCreationFee StoreKey = "poolCreationFee" // Pool creation fee amount
	StoreKeyWithdrawalFee   StoreKey = "withdrawalFee"   // Withdrawal fee in basis points
)

// poolStore implements the IPoolStore interface for pool domain storage.
// It provides type-safe access to pool data stored in the underlying KV store.
type poolStore struct {
	kvStore store.KVStore
}

// GetPools retrieves the AVL tree containing all pool data.
// This is the main data structure that stores all pool instances.
func (s *poolStore) GetPools() *avl.Tree {
	result, err := s.kvStore.Get(s.makeKey(StoreKeyPools))
	if err != nil {
		panic(err)
	}

	pools, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return pools
}

// SetPools stores the AVL tree containing all pool data.
func (s *poolStore) SetPools(pools *avl.Tree) error {
	return s.kvStore.Set(s.makeKey(StoreKeyPools), pools)
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
func (s *poolStore) GetFeeAmountTickSpacing() *avl.Tree {
	result, err := s.kvStore.Get(s.makeKey(StoreKeyFeeAmountTickSpacing))
	if err != nil {
		panic(err)
	}

	feeAmountTickSpacing, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *poolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing *avl.Tree) error {
	return s.kvStore.Set(s.makeKey(StoreKeyFeeAmountTickSpacing), feeAmountTickSpacing)
}

// GetSlot0FeeProtocol retrieves the protocol fee percentage for slot0.
func (s *poolStore) GetSlot0FeeProtocol() uint8 {
	result, err := s.kvStore.Get(s.makeKey(StoreKeySlot0FeeProtocol))
	if err != nil {
		panic(err)
	}

	slot0FeeProtocol, ok := result.(uint8)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint8: %T", result))
	}

	return slot0FeeProtocol
}

// SetSlot0FeeProtocol stores the protocol fee percentage for slot0.
func (s *poolStore) SetSlot0FeeProtocol(slot0FeeProtocol uint8) error {
	return s.kvStore.Set(s.makeKey(StoreKeySlot0FeeProtocol), slot0FeeProtocol)
}

// GetPoolCreationFee retrieves the pool creation fee amount.
func (s *poolStore) GetPoolCreationFee() int64 {
	result, err := s.kvStore.Get(s.makeKey(StoreKeyPoolCreationFee))
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
func (s *poolStore) SetPoolCreationFee(poolCreationFee int64) error {
	return s.kvStore.Set(s.makeKey(StoreKeyPoolCreationFee), poolCreationFee)
}

// GetWithdrawalFeeBPS retrieves the withdrawal fee in basis points.
func (s *poolStore) GetWithdrawalFeeBPS() uint64 {
	result, err := s.kvStore.Get(s.makeKey(StoreKeyWithdrawalFee))
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
func (s *poolStore) SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error {
	return s.kvStore.Set(s.makeKey(StoreKeyWithdrawalFee), withdrawalFeeBPS)
}

// makeKey creates a namespaced key by combining the domain address with the store key.
// This ensures that each domain has its own isolated storage namespace.
func (s *poolStore) makeKey(key StoreKey) string {
	return ufmt.Sprintf("%s:%s", s.kvStore.GetDomainAddress(), key)
}

// NewPoolStore creates a new pool store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewPoolStore(kvStore store.KVStore) IPoolStore {
	return &poolStore{
		kvStore: kvStore,
	}
}
