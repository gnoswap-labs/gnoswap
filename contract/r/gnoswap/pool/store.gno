package pool

import (
	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// StoreKey defines the keys used for storing pool data in the KV store.
// These keys are prefixed with the domain address to ensure namespace isolation.
type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	// Pool data storage keys
	StoreKeyPools                StoreKey = "pools"                // Map containing all pools
	StoreKeyFeeAmountTickSpacing StoreKey = "feeAmountTickSpacing" // Fee tier to tick spacing mapping
	StoreKeySlot0FeeProtocol     StoreKey = "slot0FeeProtocol"     // Protocol fee percentage

	// Protocol fee storage keys
	StoreKeyPoolCreationFee  StoreKey = "poolCreationFee"  // Pool creation fee amount
	StoreKeyWithdrawalFeeBPS StoreKey = "withdrawalFeeBPS" // Withdrawal fee in basis points

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

func (s *poolStore) HasPools() bool {
	return s.kvStore.Has(StoreKeyPools.String())
}

// getPoolsTree retrieves the AVL tree containing all pool data.
func (s *poolStore) getPoolsTree() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyPools.String())
	if err != nil {
		// If tree doesn't exist, return new empty tree
		return avl.NewTree()
	}

	tree, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	if tree == nil {
		panic(ufmt.Sprintf("pools tree is nil"))
	}

	return tree
}

// setPoolsTree stores the AVL tree containing all pool data.
func (s *poolStore) setPoolsTree(tree *avl.Tree) error {
	if tree == nil {
		panic(ufmt.Sprintf("pools tree is nil"))
	}

	return s.kvStore.Set(StoreKeyPools.String(), tree)
}

// GetPools retrieves the map containing all pool data.
// This is maintained for backward compatibility but converts from AVL tree.
func (s *poolStore) GetPools() map[string]*Pool {
	tree := s.getPoolsTree()

	pools := make(map[string]*Pool)
	tree.Iterate("", "", func(key string, value any) bool {
		pool, ok := value.(*Pool)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to *Pool: %T", value))
		}
		pools[key] = pool
		return false
	})

	return pools
}

// SetPools stores the map containing all pool data.
// This is maintained for backward compatibility but converts to AVL tree.
func (s *poolStore) SetPools(pools map[string]*Pool) error {
	if pools == nil {
		panic(ufmt.Sprintf("pools is nil"))
	}

	tree := avl.NewTree()
	for poolPath, pool := range pools {
		tree.Set(poolPath, pool)
	}

	return s.setPoolsTree(tree)
}

// GetPool retrieves a single pool by its path using AVL tree.
// This is more efficient than GetPools() when accessing individual pools.
func (s *poolStore) GetPool(poolPath string) (*Pool, bool) {
	tree := s.getPoolsTree()

	value, exists := tree.Get(poolPath)
	if !exists {
		return nil, false
	}

	pool, ok := value.(*Pool)
	if !ok {
		panic(ufmt.Sprintf("failed to cast value to *Pool: %T", value))
	}

	return pool, true
}

// SetPool stores a single pool by its path using AVL tree.
// This is more efficient than GetPools/SetPools when updating individual pools.
func (s *poolStore) SetPool(poolPath string, pool *Pool) error {
	if pool == nil {
		panic(ufmt.Sprintf("pool is nil"))
	}

	tree := s.getPoolsTree()
	tree.Set(poolPath, pool)

	return s.setPoolsTree(tree)
}

// GetPoolPaths retrieves all pool paths from the AVL tree.
func (s *poolStore) GetPoolPaths() []string {
	tree := s.getPoolsTree()

	paths := make([]string, 0, tree.Size())
	tree.Iterate("", "", func(key string, value any) bool {
		paths = append(paths, key)
		return false
	})

	return paths
}

// SetPoolPaths is not needed with AVL tree as paths are implicit in tree keys.
func (s *poolStore) SetPoolPaths(poolPaths []string) error {
	// No-op for AVL tree implementation
	return nil
}

// AddPoolPath is not needed with AVL tree as paths are added via SetPool.
func (s *poolStore) AddPoolPath(poolPath string) error {
	// No-op for AVL tree implementation
	return nil
}

func (s *poolStore) HasFeeAmountTickSpacing() bool {
	return s.kvStore.Has(StoreKeyFeeAmountTickSpacing.String())
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
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
		panic(ufmt.Sprintf("feeAmountTickSpacing is nil"))
	}

	return feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *poolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing map[uint32]int32) error {
	if feeAmountTickSpacing == nil {
		panic(ufmt.Sprintf("feeAmountTickSpacing is nil"))
	}

	return s.kvStore.Set(StoreKeyFeeAmountTickSpacing.String(), feeAmountTickSpacing)
}

func (s *poolStore) HasSlot0FeeProtocol() bool {
	return s.kvStore.Has(StoreKeySlot0FeeProtocol.String())
}

// GetSlot0FeeProtocol retrieves the protocol fee percentage for slot0.
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

// SetSlot0FeeProtocol stores the protocol fee percentage for slot0.
func (s *poolStore) SetSlot0FeeProtocol(slot0FeeProtocol uint8) error {
	return s.kvStore.Set(StoreKeySlot0FeeProtocol.String(), slot0FeeProtocol)
}

func (s *poolStore) HasPoolCreationFee() bool {
	return s.kvStore.Has(StoreKeyPoolCreationFee.String())
}

// GetPoolCreationFee retrieves the pool creation fee amount.
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
func (s *poolStore) SetPoolCreationFee(poolCreationFee int64) error {
	return s.kvStore.Set(StoreKeyPoolCreationFee.String(), poolCreationFee)
}

func (s *poolStore) HasWithdrawalFeeBPS() bool {
	return s.kvStore.Has(StoreKeyWithdrawalFeeBPS.String())
}

// GetWithdrawalFeeBPS retrieves the withdrawal fee in basis points.
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
func (s *poolStore) SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error {
	return s.kvStore.Set(StoreKeyWithdrawalFeeBPS.String(), withdrawalFeeBPS)
}

// HasSwapStartHook checks if the swap start hook is set.
func (s *poolStore) HasSwapStartHook() bool {
	return s.kvStore.Has(StoreKeySwapStartHook.String())
}

// GetSwapStartHook retrieves the swap start hook function.
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
func (s *poolStore) SetSwapStartHook(swapStartHook func(cur realm, poolPath string, timestamp int64)) error {
	return s.kvStore.Set(StoreKeySwapStartHook.String(), swapStartHook)
}

// HasSwapEndHook checks if the swap end hook is set.
func (s *poolStore) HasSwapEndHook() bool {
	return s.kvStore.Has(StoreKeySwapEndHook.String())
}

// GetSwapEndHook retrieves the swap end hook function.
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
func (s *poolStore) SetSwapEndHook(swapEndHook func(cur realm, poolPath string) error) error {
	return s.kvStore.Set(StoreKeySwapEndHook.String(), swapEndHook)
}

// HasTickCrossHook checks if the tick cross hook is set.
func (s *poolStore) HasTickCrossHook() bool {
	return s.kvStore.Has(StoreKeyTickCrossHook.String())
}

// GetTickCrossHook retrieves the tick cross hook function.
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
func (s *poolStore) SetTickCrossHook(tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error {
	return s.kvStore.Set(StoreKeyTickCrossHook.String(), tickCrossHook)
}

// NewPoolStore creates a new pool store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewPoolStore(kvStore store.KVStore) IPoolStore {
	return &poolStore{
		kvStore: kvStore,
	}
}
