package position

import (
	"errors"

	"gno.land/p/gnoswap/store"
	"gno.land/p/gnoswap/utils"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

type StoreKey string

// String returns the textual storage-key value.
//
// Returns:
//   - key: storage key represented as a string
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

// HasPositionsStoreKey reports whether the positions tree is present in the KV store.
//
// Returns:
//   - exists: true when the positions storage key is present
func (s *positionStore) HasPositionsStoreKey() bool {
	return s.kvStore.Has(StoreKeyPositions.String())
}

// GetPositions loads the stored tree containing all positions.
//
// Returns:
//   - positions: mutable positions tree keyed by decimal position ID; panics when the key is missing or has an unexpected type
func (s *positionStore) GetPositions() *bptree.BPTree {
	result, err := s.kvStore.Get(StoreKeyPositions.String())
	if err != nil {
		panic(err)
	}

	positions, ok := result.(*bptree.BPTree)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to *bptree.BPTree: %T", result))
	}

	return positions
}

// SetPositions stores the positions tree after validating the realm context.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context; the store requires it to be the current realm
//   - positions: positions tree to persist under the positions storage key
//
// Returns:
//   - err: nil when the tree is stored; non-nil when rlm is spoofed or the KV write fails
func (s *positionStore) SetPositions(_ int, rlm realm, positions *bptree.BPTree) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPositions.String(), positions)
}

// HasPositionNextIDStoreKey reports whether the next-position-ID value is present in the KV store.
//
// Returns:
//   - exists: true when the next-position-ID storage key is present
func (s *positionStore) HasPositionNextIDStoreKey() bool {
	return s.kvStore.Has(StoreKeyPositionNextID.String())
}

// GetPositionNextID loads the next position NFT ID to allocate.
//
// Returns:
//   - nextID: next position ID stored by the position manager; panics when the key is missing or has an unexpected type
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

// SetPositionNextID stores the next position NFT ID after validating the realm context.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context; the store requires it to be the current realm
//   - nextID: next position ID to persist for the next mint
//
// Returns:
//   - err: nil when nextID is stored; non-nil when rlm is spoofed or the KV write fails
func (s *positionStore) SetPositionNextID(_ int, rlm realm, nextID uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	return s.kvStore.Set(0, rlm, StoreKeyPositionNextID.String(), nextID)
}

// HasPosition reports whether a position is stored for the supplied NFT ID.
//
// Parameters:
//   - positionId: position NFT token ID to look up
//
// Returns:
//   - exists: true when the decimal positionId key exists in the positions tree
func (s *positionStore) HasPosition(positionId uint64) bool {
	positions := s.GetPositions()

	return positions.Has(utils.Uint64ToString(positionId))
}

// GetPosition loads a position by NFT ID.
//
// Parameters:
//   - positionId: position NFT token ID to look up
//
// Returns:
//   - position: stored position value when present, or the zero Position when absent
//   - exists: true when positionId is present; false when no position is stored for that ID
func (s *positionStore) GetPosition(positionId uint64) (Position, bool) {
	positions := s.GetPositions()

	result := positions.Get(utils.Uint64ToString(positionId))
	if result == nil {
		return Position{}, false
	}

	position, ok := result.(Position)
	if !ok {
		panic(ufmt.Sprintf("failed to cast result to Position: %T", result))
	}

	return position, true
}

// SetPosition inserts or replaces a position after validating the realm context.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context; the store requires it to be the current realm
//   - positionId: position NFT token ID used as the tree key
//   - position: position value to persist
//
// Returns:
//   - err: nil when the position is stored; non-nil when rlm is spoofed, the positions key is missing, or the KV write fails
func (s *positionStore) SetPosition(_ int, rlm realm, positionId uint64, position Position) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasPositionsStoreKey() {
		return errors.New("positions store key not found")
	}

	positions := s.GetPositions()

	positions.Set(utils.Uint64ToString(positionId), position)

	return s.kvStore.Set(0, rlm, StoreKeyPositions.String(), positions)
}

// RemovePosition deletes a position after validating the realm context.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context; the store requires it to be the current realm
//   - positionId: position NFT token ID to remove from the positions tree
//
// Returns:
//   - err: nil when the position is removed and the tree is stored; non-nil when rlm is spoofed, the positions key is missing, or the KV write fails
func (s *positionStore) RemovePosition(_ int, rlm realm, positionId uint64) error {
	if !rlm.IsCurrent() {
		return errors.New(ErrSpoofedRealm)
	}

	if !s.HasPositionsStoreKey() {
		return errors.New("positions store key not found")
	}

	positions := s.GetPositions()

	positions.Remove(utils.Uint64ToString(positionId))

	return s.kvStore.Set(0, rlm, StoreKeyPositions.String(), positions)
}

// NewPositionStore creates a position store backed by the provided KV store.
// The upgrade system uses it to construct storage instances for each implementation.
//
// Parameters:
//   - kvStore: Domain-owned KV store shared by position implementations.
//
// Returns:
//   - IPositionStore: Position storage wrapper backed by the supplied store.
func NewPositionStore(kvStore store.KVStore) IPositionStore {
	return &positionStore{
		kvStore: kvStore,
	}
}
