package mock

import (
	"strconv"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/position"
)

// Mock Position Store
type MockPositionStore struct {
	positions *avl.Tree
	nextID    uint64
}

func (s *MockPositionStore) HasPositionsStoreKey() bool {
	return false
}

func (s *MockPositionStore) GetPositions() *avl.Tree {
	return s.positions
}

func (s *MockPositionStore) SetPositions(positions *avl.Tree) error {
	s.positions = positions
	return nil
}

func (s *MockPositionStore) HasPositionNextIDStoreKey() bool {
	return false
}

func (s *MockPositionStore) GetPositionNextID() uint64 {
	return s.nextID
}

func (s *MockPositionStore) SetPositionNextID(nextID uint64) error {
	s.nextID = nextID
	return nil
}

func (s *MockPositionStore) HasPosition(positionId uint64) bool {
	return s.positions.Has(strconv.FormatUint(positionId, 10))
}

func (s *MockPositionStore) GetPosition(positionId uint64) (position.Position, bool) {
	value, exists := s.positions.Get(strconv.FormatUint(positionId, 10))
	if !exists {
		return position.Position{}, false
	}

	return value.(position.Position), true
}

func (s *MockPositionStore) SetPosition(positionId uint64, position position.Position) error {
	s.positions.Set(strconv.FormatUint(positionId, 10), position)
	return nil
}

func (s *MockPositionStore) RemovePosition(positionId uint64) error {
	s.positions.Remove(strconv.FormatUint(positionId, 10))
	return nil
}

// Mock NFT Accessor
type MockNFTAccessor struct {
	approved map[grc721.TokenID]map[address]bool
	owners   map[grc721.TokenID]address
}

func (n *MockNFTAccessor) Approve(approved address, tid grc721.TokenID) error {
	n.approved[tid][approved] = true
	return nil
}

func (n *MockNFTAccessor) Mint(to address, tid grc721.TokenID) grc721.TokenID {
	n.owners[tid] = to
	n.approved[tid] = make(map[address]bool)
	return tid
}

func (n *MockNFTAccessor) Burn(tid grc721.TokenID) {
	delete(n.owners, tid)
	delete(n.approved, tid)
}

func (n *MockNFTAccessor) TotalSupply() int64 {
	return int64(len(n.owners))
}

func (n *MockNFTAccessor) Exists(tid grc721.TokenID) bool {
	return n.owners[tid] != ""
}

func (n *MockNFTAccessor) OwnerOf(tid grc721.TokenID) (address, error) {
	if _, ok := n.owners[tid]; !ok {
		return "", grc721.ErrCallerIsNotOwner
	}

	return n.owners[tid], nil
}

func (n *MockNFTAccessor) SetOwner(tid grc721.TokenID, owner address) error {
	n.owners[tid] = owner
	return nil
}

func NewMockPositionStore() *MockPositionStore {
	store := &MockPositionStore{positions: avl.NewTree(), nextID: 1}
	return store
}

func NewMockNFTAccessor() *MockNFTAccessor {
	return &MockNFTAccessor{approved: make(map[grc721.TokenID]map[address]bool), owners: make(map[grc721.TokenID]address)}
}
