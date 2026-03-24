package mock

import (
	avl "gno.land/p/nt/avl/v0"
	pl "gno.land/r/gnoswap/pool"
)

type MockPoolStore struct {
	pools                *avl.Tree
	poolTicks            *avl.Tree
	tickBitmaps          *avl.Tree
	positions            *avl.Tree
	observationStates    *avl.Tree
	feeAmountTickSpacing map[uint32]int32
	slot0FeeProtocol     uint8
	poolCreationFee      int64
	withdrawalFeeBPS     uint64
	swapStartHook        func(cur realm, poolPath string, timestamp int64)
	swapEndHook          func(cur realm, poolPath string) error
	tickCrossHook        func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)
}

func (s *MockPoolStore) HasPools() bool {
	return s.pools != nil
}

// GetPools retrieves the map containing all pool data.
// This is the main data structure that stores all pool instances.
func (s *MockPoolStore) GetPools() *avl.Tree {
	return s.pools
}

// SetPools stores the map containing all pool data.
func (s *MockPoolStore) SetPools(pools *avl.Tree) error {
	s.pools = pools
	return nil
}

func (s *MockPoolStore) HasPoolTicksBucket() bool {
	return s.poolTicks != nil
}

func (s *MockPoolStore) GetPoolTicksBucket() *avl.Tree {
	return s.poolTicks
}

func (s *MockPoolStore) SetPoolTicksBucket(bucket *avl.Tree) error {
	s.poolTicks = bucket
	return nil
}

func (s *MockPoolStore) HasPoolTickBitmapsBucket() bool {
	return s.tickBitmaps != nil
}

func (s *MockPoolStore) GetPoolTickBitmapsBucket() *avl.Tree {
	return s.tickBitmaps
}

func (s *MockPoolStore) SetPoolTickBitmapsBucket(bucket *avl.Tree) error {
	s.tickBitmaps = bucket
	return nil
}

func (s *MockPoolStore) HasPoolPositionsBucket() bool {
	return s.positions != nil
}

func (s *MockPoolStore) GetPoolPositionsBucket() *avl.Tree {
	return s.positions
}

func (s *MockPoolStore) SetPoolPositionsBucket(bucket *avl.Tree) error {
	s.positions = bucket
	return nil
}

func (s *MockPoolStore) HasPoolObservationsBucket() bool {
	return s.observationStates != nil
}

func (s *MockPoolStore) GetPoolObservationsBucket() *avl.Tree {
	return s.observationStates
}

func (s *MockPoolStore) SetPoolObservationsBucket(bucket *avl.Tree) error {
	s.observationStates = bucket
	return nil
}

func (s *MockPoolStore) GetPoolTicks(poolPath string) *avl.Tree {
	result, _ := s.poolTicks.Get(poolPath)
	ticks, _ := result.(*avl.Tree)
	return ticks
}

func (s *MockPoolStore) SetPoolTicks(poolPath string, ticks *avl.Tree) error {
	s.poolTicks.Set(poolPath, ticks)
	return nil
}

func (s *MockPoolStore) GetPoolTickBitmaps(poolPath string) *avl.Tree {
	result, _ := s.tickBitmaps.Get(poolPath)
	tickBitmaps, _ := result.(*avl.Tree)
	return tickBitmaps
}

func (s *MockPoolStore) SetPoolTickBitmaps(poolPath string, tickBitmaps *avl.Tree) error {
	s.tickBitmaps.Set(poolPath, tickBitmaps)
	return nil
}

func (s *MockPoolStore) GetPoolPositions(poolPath string) *avl.Tree {
	result, _ := s.positions.Get(poolPath)
	positions, _ := result.(*avl.Tree)
	return positions
}

func (s *MockPoolStore) SetPoolPositions(poolPath string, positions *avl.Tree) error {
	s.positions.Set(poolPath, positions)
	return nil
}

func (s *MockPoolStore) GetPoolObservationState(poolPath string) *pl.ObservationState {
	result, _ := s.observationStates.Get(poolPath)
	observationState, _ := result.(*pl.ObservationState)
	return observationState
}

func (s *MockPoolStore) SetPoolObservationState(poolPath string, observationState *pl.ObservationState) error {
	s.observationStates.Set(poolPath, observationState)
	return nil
}

func (s *MockPoolStore) HasFeeAmountTickSpacing() bool {
	return s.feeAmountTickSpacing != nil
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
func (s *MockPoolStore) GetFeeAmountTickSpacing() map[uint32]int32 {
	return s.feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *MockPoolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing map[uint32]int32) error {
	s.feeAmountTickSpacing = feeAmountTickSpacing
	return nil
}

func (s *MockPoolStore) HasSlot0FeeProtocol() bool {
	return true
}

// GetSlot0FeeProtocol retrieves the protocol fee percentage for slot0.
func (s *MockPoolStore) GetSlot0FeeProtocol() uint8 {
	return s.slot0FeeProtocol
}

// SetSlot0FeeProtocol stores the protocol fee percentage for slot0.
func (s *MockPoolStore) SetSlot0FeeProtocol(slot0FeeProtocol uint8) error {
	s.slot0FeeProtocol = slot0FeeProtocol
	return nil
}

func (s *MockPoolStore) HasPoolCreationFee() bool {
	return true
}

// GetPoolCreationFee retrieves the pool creation fee amount.
func (s *MockPoolStore) GetPoolCreationFee() int64 {
	return s.poolCreationFee
}

// SetPoolCreationFee stores the pool creation fee amount.
func (s *MockPoolStore) SetPoolCreationFee(poolCreationFee int64) error {
	s.poolCreationFee = poolCreationFee
	return nil
}

func (s *MockPoolStore) HasWithdrawalFeeBPS() bool {
	return true
}

// GetWithdrawalFeeBPS retrieves the withdrawal fee in basis points.
func (s *MockPoolStore) GetWithdrawalFeeBPS() uint64 {
	return s.withdrawalFeeBPS
}

// SetWithdrawalFeeBPS stores the withdrawal fee in basis points.
func (s *MockPoolStore) SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error {
	s.withdrawalFeeBPS = withdrawalFeeBPS
	return nil
}

// HasSwapStartHook checks if the swap start hook is set.
func (s *MockPoolStore) HasSwapStartHook() bool {
	return s.swapStartHook != nil
}

// GetSwapStartHook retrieves the swap start hook function.
func (s *MockPoolStore) GetSwapStartHook() func(cur realm, poolPath string, timestamp int64) {
	return s.swapStartHook
}

// SetSwapStartHook stores the swap start hook function.
func (s *MockPoolStore) SetSwapStartHook(swapStartHook func(cur realm, poolPath string, timestamp int64)) error {
	s.swapStartHook = swapStartHook
	return nil
}

// HasSwapEndHook checks if the swap end hook is set.
func (s *MockPoolStore) HasSwapEndHook() bool {
	return s.swapEndHook != nil
}

// GetSwapEndHook retrieves the swap end hook function.
func (s *MockPoolStore) GetSwapEndHook() func(cur realm, poolPath string) error {
	return s.swapEndHook
}

// SetSwapEndHook stores the swap end hook function.
func (s *MockPoolStore) SetSwapEndHook(swapEndHook func(cur realm, poolPath string) error) error {
	s.swapEndHook = swapEndHook
	return nil
}

// HasTickCrossHook checks if the tick cross hook is set.
func (s *MockPoolStore) HasTickCrossHook() bool {
	return s.tickCrossHook != nil
}

// GetTickCrossHook retrieves the tick cross hook function.
func (s *MockPoolStore) GetTickCrossHook() func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	return s.tickCrossHook
}

// SetTickCrossHook stores the tick cross hook function.
func (s *MockPoolStore) SetTickCrossHook(tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error {
	s.tickCrossHook = tickCrossHook
	return nil
}

func NewMockPoolStore() *MockPoolStore {
	return NewMockPoolStoreWithHook(nil, nil, nil)
}

func NewMockPoolStoreWithHook(
	swapStartHook func(cur realm, poolPath string, timestamp int64),
	swapEndHook func(cur realm, poolPath string) error,
	tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64),
) *MockPoolStore {
	feeAmountTickSpacing := map[uint32]int32{
		100:   1,
		500:   10,
		3000:  60,
		10000: 200,
	}

	return &MockPoolStore{
		pools:                avl.NewTree(),
		poolTicks:            avl.NewTree(),
		tickBitmaps:          avl.NewTree(),
		positions:            avl.NewTree(),
		observationStates:    avl.NewTree(),
		feeAmountTickSpacing: feeAmountTickSpacing,
		slot0FeeProtocol:     0,
		poolCreationFee:      100_000_000,
		withdrawalFeeBPS:     100,
		swapStartHook:        swapStartHook,
		swapEndHook:          swapEndHook,
		tickCrossHook:        tickCrossHook,
	}
}
