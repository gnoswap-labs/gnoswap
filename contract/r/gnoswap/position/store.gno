package position

import (
	"errors"
	"strconv"

	"gno.land/p/gnoswap/store"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

type StoreKey string

func (s StoreKey) String() string {
	return string(s)
}

const (
	StoreKeyPositions      StoreKey = "positions"      // Positions
	StoreKeyPositionNextID StoreKey = "positionNextID" // Position next ID
)

type positionStore struct {
	kvStore store.KVStore
}

func (s *positionStore) HasPositionsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPositions.String())
}

func (s *positionStore) GetPositions() *avl.Tree {
	result, err := s.kvStore.Get(StoreKeyPositions.String())
	if err != nil {
		panic(err)
	}

	positions, ok := result.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *avl.Tree: %T", result))
	}

	return positions
}

func (s *positionStore) SetPositions(positions *avl.Tree) error {
	return s.kvStore.Set(StoreKeyPositions.String(), positions)
}

func (s *positionStore) HasPositionNextIDStoreKey() bool {
	return s.kvStore.Has(StoreKeyPositionNextID.String())
}

func (s *positionStore) GetPositionNextID() uint64 {
	result, err := s.kvStore.Get(StoreKeyPositionNextID.String())
	if err != nil {
		panic(err)
	}

	nextID, ok := result.(uint64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to uint64: %T", result))
	}

	return nextID
}

func (s *positionStore) SetPositionNextID(nextID uint64) error {
	return s.kvStore.Set(StoreKeyPositionNextID.String(), nextID)
}

func (s *positionStore) HasPosition(positionId uint64) bool {
	positions := s.GetPositions()

	return positions.Has(uint64ToString(positionId))
}

func (s *positionStore) GetPosition(positionId uint64) (Position, bool) {
	positions := s.GetPositions()

	result, ok := positions.Get(uint64ToString(positionId))
	if !ok {
		return Position{}, false
	}

	position, ok := result.(Position)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Position: %T", result))
	}

	return position, true
}

func (s *positionStore) SetPosition(positionId uint64, position Position) error {
	if !s.HasPositionsStoreKey() {
		return errors.New("positions store key not found")
	}

	positions := s.GetPositions()

	positions.Set(uint64ToString(positionId), position)

	return s.kvStore.Set(StoreKeyPositions.String(), positions)
}

func (s *positionStore) RemovePosition(positionId uint64) error {
	if !s.HasPositionsStoreKey() {
		return errors.New("positions store key not found")
	}

	positions := s.GetPositions()

	positions.Remove(uint64ToString(positionId))

	return s.kvStore.Set(StoreKeyPositions.String(), positions)
}

// NewPositionStore creates a new protocol fee store instance with the provided KV store.
// This function is used by the upgrade system to create storage instances for each implementation.
func NewPositionStore(kvStore store.KVStore) IPositionStore {
	return &positionStore{
		kvStore: kvStore,
	}
}

func uint64ToString(id uint64) string {
	return strconv.FormatUint(id, 10)
}
