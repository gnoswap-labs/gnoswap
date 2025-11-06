package fuzzing

import (
	"strconv"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"
)

type mockPoolStore struct {
	pools                *avl.Tree
	feeAmountTickSpacing *avl.Tree
	slot0FeeProtocol     uint8
	poolCreationFee      int64
	withdrawalFeeBPS     uint64
	swapStartHook        func(cur realm, poolPath string, timestamp int64)
	swapEndHook          func(cur realm, poolPath string) error
	tickCrossHook        func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)
}

func (s *mockPoolStore) HasPools() bool {
	return s.pools != nil
}

// GetPools retrieves the AVL tree containing all pool data.
// This is the main data structure that stores all pool instances.
func (s *mockPoolStore) GetPools() *avl.Tree {
	return s.pools
}

// SetPools stores the AVL tree containing all pool data.
func (s *mockPoolStore) SetPools(pools *avl.Tree) error {
	s.pools = pools
	return nil
}

func (s *mockPoolStore) HasFeeAmountTickSpacing() bool {
	return s.feeAmountTickSpacing != nil
}

// GetFeeAmountTickSpacing retrieves the mapping between fee amounts and tick spacing.
// This mapping determines the tick spacing for each supported fee tier.
func (s *mockPoolStore) GetFeeAmountTickSpacing() *avl.Tree {
	return s.feeAmountTickSpacing
}

// SetFeeAmountTickSpacing stores the mapping between fee amounts and tick spacing.
func (s *mockPoolStore) SetFeeAmountTickSpacing(feeAmountTickSpacing *avl.Tree) error {
	s.feeAmountTickSpacing = feeAmountTickSpacing
	return nil
}

func (s *mockPoolStore) HasSlot0FeeProtocol() bool {
	return true
}

// GetSlot0FeeProtocol retrieves the protocol fee percentage for slot0.
func (s *mockPoolStore) GetSlot0FeeProtocol() uint8 {
	return s.slot0FeeProtocol
}

// SetSlot0FeeProtocol stores the protocol fee percentage for slot0.
func (s *mockPoolStore) SetSlot0FeeProtocol(slot0FeeProtocol uint8) error {
	s.slot0FeeProtocol = slot0FeeProtocol
	return nil
}

func (s *mockPoolStore) HasPoolCreationFee() bool {
	return true
}

// GetPoolCreationFee retrieves the pool creation fee amount.
func (s *mockPoolStore) GetPoolCreationFee() int64 {
	return s.poolCreationFee
}

// SetPoolCreationFee stores the pool creation fee amount.
func (s *mockPoolStore) SetPoolCreationFee(poolCreationFee int64) error {
	s.poolCreationFee = poolCreationFee
	return nil
}

func (s *mockPoolStore) HasWithdrawalFeeBPS() bool {
	return true
}

// GetWithdrawalFeeBPS retrieves the withdrawal fee in basis points.
func (s *mockPoolStore) GetWithdrawalFeeBPS() uint64 {
	return s.withdrawalFeeBPS
}

// SetWithdrawalFeeBPS stores the withdrawal fee in basis points.
func (s *mockPoolStore) SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) error {
	s.withdrawalFeeBPS = withdrawalFeeBPS
	return nil
}

// HasSwapStartHook checks if the swap start hook is set.
func (s *mockPoolStore) HasSwapStartHook() bool {
	return s.swapStartHook != nil
}

// GetSwapStartHook retrieves the swap start hook function.
func (s *mockPoolStore) GetSwapStartHook() func(cur realm, poolPath string, timestamp int64) {
	return s.swapStartHook
}

// SetSwapStartHook stores the swap start hook function.
func (s *mockPoolStore) SetSwapStartHook(swapStartHook func(cur realm, poolPath string, timestamp int64)) error {
	s.swapStartHook = swapStartHook
	return nil
}

// HasSwapEndHook checks if the swap end hook is set.
func (s *mockPoolStore) HasSwapEndHook() bool {
	return s.swapEndHook != nil
}

// GetSwapEndHook retrieves the swap end hook function.
func (s *mockPoolStore) GetSwapEndHook() func(cur realm, poolPath string) error {
	return s.swapEndHook
}

// SetSwapEndHook stores the swap end hook function.
func (s *mockPoolStore) SetSwapEndHook(swapEndHook func(cur realm, poolPath string) error) error {
	s.swapEndHook = swapEndHook
	return nil
}

// HasTickCrossHook checks if the tick cross hook is set.
func (s *mockPoolStore) HasTickCrossHook() bool {
	return s.tickCrossHook != nil
}

// GetTickCrossHook retrieves the tick cross hook function.
func (s *mockPoolStore) GetTickCrossHook() func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64) {
	return s.tickCrossHook
}

// SetTickCrossHook stores the tick cross hook function.
func (s *mockPoolStore) SetTickCrossHook(tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error {
	s.tickCrossHook = tickCrossHook
	return nil
}

func NewMockPoolStore() *mockPoolStore {
	return NewMockPoolStoreWithHook(nil, nil, nil)
}

func NewMockPoolStoreWithHook(
	swapStartHook func(cur realm, poolPath string, timestamp int64),
	swapEndHook func(cur realm, poolPath string) error,
	tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64),
) *mockPoolStore {
	feeAmountTickSpacing := avl.NewTree()
	feeAmountTickSpacing.Set("100", int32(1))
	feeAmountTickSpacing.Set("500", int32(10))
	feeAmountTickSpacing.Set("3000", int32(60))
	feeAmountTickSpacing.Set("10000", int32(200))

	return &mockPoolStore{
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

// Mock Position Store
type mockPositionStore struct {
	positions *avl.Tree
	nextID    uint64
}

func (s *mockPositionStore) HasPositionsStoreKey() bool {
	return false
}

func (s *mockPositionStore) GetPositions() *avl.Tree {
	return s.positions
}

func (s *mockPositionStore) SetPositions(positions *avl.Tree) error {
	s.positions = positions
	return nil
}

func (s *mockPositionStore) HasPositionNextIDStoreKey() bool {
	return false
}

func (s *mockPositionStore) GetPositionNextID() uint64 {
	return s.nextID
}

func (s *mockPositionStore) SetPositionNextID(nextID uint64) error {
	s.nextID = nextID
	return nil
}

func (s *mockPositionStore) HasPosition(positionId uint64) bool {
	return s.positions.Has(strconv.FormatUint(positionId, 10))
}

func (s *mockPositionStore) GetPosition(positionId uint64) (position.Position, bool) {
	value, exists := s.positions.Get(strconv.FormatUint(positionId, 10))
	if !exists {
		return position.Position{}, false
	}
	return value.(position.Position), true
}

func (s *mockPositionStore) SetPosition(positionId uint64, position position.Position) error {
	s.positions.Set(strconv.FormatUint(positionId, 10), position)
	return nil
}

func (s *mockPositionStore) RemovePosition(positionId uint64) error {
	s.positions.Remove(strconv.FormatUint(positionId, 10))
	return nil
}

func newmockPositionStore() position.IPositionStore {
	return &mockPositionStore{positions: avl.NewTree(), nextID: 1}
}

// Mock Router Store
type mockRouterStore struct {
	data map[string]any
}

func (r *mockRouterStore) HasSwapFeeKey() bool {
	return r.data[router.StoreKeySwapFee.String()] != nil
}

func (r *mockRouterStore) GetSwapFee() uint64 {
	return r.data[router.StoreKeySwapFee.String()].(uint64)
}

func (r *mockRouterStore) SetSwapFee(fee uint64) error {
	r.data[router.StoreKeySwapFee.String()] = fee
	return nil
}

// Mock NFT Accessor
type mockNFTAccessor struct {
	approved map[grc721.TokenID]map[address]bool
	owners   map[grc721.TokenID]address
}

func (n *mockNFTAccessor) Approve(approved address, tid grc721.TokenID) error {
	n.approved[tid][approved] = true
	return nil
}

func (n *mockNFTAccessor) Mint(to address, tid grc721.TokenID) grc721.TokenID {
	n.owners[tid] = to
	n.approved[tid] = make(map[address]bool)
	return tid
}

func (n *mockNFTAccessor) Burn(tid grc721.TokenID) {
	delete(n.owners, tid)
	delete(n.approved, tid)
}

func (n *mockNFTAccessor) TotalSupply() int64 {
	return int64(len(n.owners))
}

func (n *mockNFTAccessor) Exists(tid grc721.TokenID) bool {
	return n.owners[tid] != ""
}

func (n *mockNFTAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	if _, ok := n.owners[tid]; !ok {
		return "", grc721.ErrCallerIsNotOwner
	}

	return n.owners[tid], nil
}

func newMockPositionStore() *mockPositionStore {
	return &mockPositionStore{positions: avl.NewTree(), nextID: 1}
}

// Initialize Mock Instances
func newMockRouterStore() *mockRouterStore {
	data := make(map[string]any)
	data[router.StoreKeySwapFee.String()] = uint64(15) // 0.15%

	return &mockRouterStore{data: data}
}

func newMockNFTAccessor() *mockNFTAccessor {
	return &mockNFTAccessor{approved: make(map[grc721.TokenID]map[address]bool), owners: make(map[grc721.TokenID]address)}
}
