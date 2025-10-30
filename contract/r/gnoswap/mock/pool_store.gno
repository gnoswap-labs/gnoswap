package mock

import (
	"gno.land/p/nt/avl"
)

type MockPoolStore struct {
	pools                *avl.Tree
	feeAmountTickSpacing *avl.Tree
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

// GetPools retrieves the AVL tree containing all pool data.
// This is the main data structure that stores all pool instances.
func (s *MockPoolStore) GetPools() *avl.Tree {
	return s.pools
}

// SetPools stores the AVL tree containing all pool data.
func (s *MockPoolStore) SetPools(pools *avl.Tree) error {
	s.pools = pools
	return nil
}

func (s *MockPoolStore) HasFeeAmountTickSpacing() bool {
	return s.feeAmountTickSpacing != nil
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
func (s *MockPoolStore) GetFeeAmountTickSpacing() *avl.Tree {
	return s.feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *MockPoolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing *avl.Tree) error {
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
	feeAmountTickSpacing := avl.NewTree()
	feeAmountTickSpacing.Set("100", int32(1))
	feeAmountTickSpacing.Set("500", int32(10))
	feeAmountTickSpacing.Set("3000", int32(60))
	feeAmountTickSpacing.Set("10000", int32(200))

	return &MockPoolStore{
		pools:                avl.NewTree(),
		feeAmountTickSpacing: feeAmountTickSpacing,
		slot0FeeProtocol:     0,
		poolCreationFee:      100_000_000,
		withdrawalFeeBPS:     100,
		swapStartHook:        swapStartHook,
		swapEndHook:          swapEndHook,
		tickCrossHook:        tickCrossHook,
	}
}
