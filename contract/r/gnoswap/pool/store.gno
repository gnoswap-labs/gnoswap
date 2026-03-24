package pool

import (
	"gno.land/p/gnoswap/store"
	avl "gno.land/p/nt/avl/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
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
	StoreKeyPoolTicks            StoreKey = "pool:ticks"           // AVL bucket of per-pool ticks trees
	StoreKeyPoolTickBitmaps      StoreKey = "pool:tickBitmaps"     // AVL bucket of per-pool tick bitmaps
	StoreKeyPoolPositions        StoreKey = "pool:positions"       // AVL bucket of per-pool positions trees
	StoreKeyPoolObservations     StoreKey = "pool:observations"    // AVL bucket of per-pool observation state
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

// GetPools retrieves the map containing all pool data.
// This is the main data structure that stores all pool instances.
func (s *poolStore) GetPools() *avl.Tree {
	pools, err := s.kvStore.GetTree(StoreKeyPools.String())
	if err != nil {
		panic(err)
	}

	if pools == nil {
		panic("pools is nil")
	}

	return pools
}

// SetPools stores the map containing all pool data.
func (s *poolStore) SetPools(pools *avl.Tree) error {
	if pools == nil {
		panic("pools is nil")
	}

	return s.kvStore.Set(StoreKeyPools.String(), pools)
}

func (s *poolStore) HasPoolTicksBucket() bool {
	return s.kvStore.Has(StoreKeyPoolTicks.String())
}

func (s *poolStore) GetPoolTicksBucket() *avl.Tree {
	bucket, err := s.kvStore.GetTree(StoreKeyPoolTicks.String())
	if err != nil {
		panic(err)
	}

	if bucket == nil {
		panic("pool ticks bucket is nil")
	}

	return bucket
}

func (s *poolStore) SetPoolTicksBucket(bucket *avl.Tree) error {
	if bucket == nil {
		panic("pool ticks bucket is nil")
	}

	return s.kvStore.Set(StoreKeyPoolTicks.String(), bucket)
}

func (s *poolStore) HasPoolTickBitmapsBucket() bool {
	return s.kvStore.Has(StoreKeyPoolTickBitmaps.String())
}

func (s *poolStore) GetPoolTickBitmapsBucket() *avl.Tree {
	bucket, err := s.kvStore.GetTree(StoreKeyPoolTickBitmaps.String())
	if err != nil {
		panic(err)
	}

	if bucket == nil {
		panic("pool tick bitmaps bucket is nil")
	}

	return bucket
}

func (s *poolStore) SetPoolTickBitmapsBucket(bucket *avl.Tree) error {
	if bucket == nil {
		panic("pool tick bitmaps bucket is nil")
	}

	return s.kvStore.Set(StoreKeyPoolTickBitmaps.String(), bucket)
}

func (s *poolStore) HasPoolPositionsBucket() bool {
	return s.kvStore.Has(StoreKeyPoolPositions.String())
}

func (s *poolStore) GetPoolPositionsBucket() *avl.Tree {
	bucket, err := s.kvStore.GetTree(StoreKeyPoolPositions.String())
	if err != nil {
		panic(err)
	}

	if bucket == nil {
		panic("pool positions bucket is nil")
	}

	return bucket
}

func (s *poolStore) SetPoolPositionsBucket(bucket *avl.Tree) error {
	if bucket == nil {
		panic("pool positions bucket is nil")
	}

	return s.kvStore.Set(StoreKeyPoolPositions.String(), bucket)
}

func (s *poolStore) HasPoolObservationsBucket() bool {
	return s.kvStore.Has(StoreKeyPoolObservations.String())
}

func (s *poolStore) GetPoolObservationsBucket() *avl.Tree {
	bucket, err := s.kvStore.GetTree(StoreKeyPoolObservations.String())
	if err != nil {
		panic(err)
	}

	if bucket == nil {
		panic("pool observations bucket is nil")
	}

	return bucket
}

func (s *poolStore) SetPoolObservationsBucket(bucket *avl.Tree) error {
	if bucket == nil {
		panic("pool observations bucket is nil")
	}

	return s.kvStore.Set(StoreKeyPoolObservations.String(), bucket)
}

func (s *poolStore) GetPoolTicks(poolPath string) *avl.Tree {
	bucket := s.GetPoolTicksBucket()
	result, ok := bucket.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("ticks not found for poolPath: %s", poolPath))
	}

	ticks, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast ticks to *avl.Tree: %T", result))
	}
	if ticks == nil {
		panic("ticks is nil")
	}
	return ticks
}

func (s *poolStore) SetPoolTicks(poolPath string, ticks *avl.Tree) error {
	if ticks == nil {
		panic("ticks is nil")
	}

	bucket := s.GetPoolTicksBucket()
	bucket.Set(poolPath, ticks)

	return s.SetPoolTicksBucket(bucket)
}

func (s *poolStore) GetPoolTickBitmaps(poolPath string) *avl.Tree {
	bucket := s.GetPoolTickBitmapsBucket()
	result, ok := bucket.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("tick bitmaps not found for poolPath: %s", poolPath))
	}

	tickBitmaps, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast tickBitmaps to *avl.Tree: %T", result))
	}
	if tickBitmaps == nil {
		panic("tickBitmaps is nil")
	}
	return tickBitmaps
}

func (s *poolStore) SetPoolTickBitmaps(poolPath string, tickBitmaps *avl.Tree) error {
	if tickBitmaps == nil {
		panic("tickBitmaps is nil")
	}

	bucket := s.GetPoolTickBitmapsBucket()
	bucket.Set(poolPath, tickBitmaps)

	return s.SetPoolTickBitmapsBucket(bucket)
}

func (s *poolStore) GetPoolPositions(poolPath string) *avl.Tree {
	bucket := s.GetPoolPositionsBucket()
	result, ok := bucket.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("positions not found for poolPath: %s", poolPath))
	}

	positions, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast positions to *avl.Tree: %T", result))
	}
	if positions == nil {
		panic("positions is nil")
	}
	return positions
}

func (s *poolStore) SetPoolPositions(poolPath string, positions *avl.Tree) error {
	if positions == nil {
		panic("positions is nil")
	}

	bucket := s.GetPoolPositionsBucket()
	bucket.Set(poolPath, positions)

	return s.SetPoolPositionsBucket(bucket)
}

func (s *poolStore) GetPoolObservationState(poolPath string) *ObservationState {
	bucket := s.GetPoolObservationsBucket()
	result, ok := bucket.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("observationState not found for poolPath: %s", poolPath))
	}

	observationState, ok := result.(*ObservationState)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *ObservationState: %T", result))
	}
	if observationState == nil {
		panic("observationState is nil")
	}
	return observationState
}

func (s *poolStore) SetPoolObservationState(poolPath string, observationState *ObservationState) error {
	if observationState == nil {
		panic("observationState is nil")
	}

	bucket := s.GetPoolObservationsBucket()
	bucket.Set(poolPath, observationState)

	return s.SetPoolObservationsBucket(bucket)
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
		panic("feeAmountTickSpacing is nil")
	}

	return feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *poolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing map[uint32]int32) error {
	if feeAmountTickSpacing == nil {
		panic("feeAmountTickSpacing is nil")
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
