package v1

import (
	"strconv"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/position"
)

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

func newMockPosition() *positionV1 {
	return &positionV1{store: newMockPositionStore(), nftAccessor: newMockNFTAccessor()}
}

func newMockPositionStore() *mockPositionStore {
	store := &mockPositionStore{positions: avl.NewTree(), nextID: 1}
	return store
}

func newMockNFTAccessor() *mockNFTAccessor {
	return &mockNFTAccessor{approved: make(map[grc721.TokenID]map[address]bool), owners: make(map[grc721.TokenID]address)}
}
