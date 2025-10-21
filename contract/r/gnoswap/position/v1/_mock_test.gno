package v1

import (
	"strconv"
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/v1/pool"
)

type positionStore struct {
	data map[string]any
}

func (r *positionStore) HasPositionNextIDStoreKey() bool {
	return r.data[position.StoreKeyPositionNextID.String()] != nil
}

func (r *positionStore) GetPositionNextID() uint64 {
	return r.data[position.StoreKeyPositionNextID.String()].(uint64)
}

func (r *positionStore) SetPositionNextID(nextID uint64) error {
	r.data[position.StoreKeyPositionNextID.String()] = nextID
	return nil
}

func (r *positionStore) HasPositionsStoreKey() bool {
	return r.data[position.StoreKeyPositions.String()] != nil
}

func (r *positionStore) GetPositions() *avl.Tree {
	return r.data[position.StoreKeyPositions.String()].(*avl.Tree)
}

func (r *positionStore) SetPositions(positions *avl.Tree) error {
	r.data[position.StoreKeyPositions.String()] = positions
	return nil
}

func (r *positionStore) HasPosition(positionId uint64) bool {
	return r.data[position.StoreKeyPositions.String()].(*avl.Tree).Has(strconv.FormatUint(positionId, 10))
}

func (r *positionStore) GetPosition(positionId uint64) (position.Position, bool) {
	return r.data[position.StoreKeyPositions.String()].(*avl.Tree).Get(strconv.FormatUint(positionId, 10)).(position.Position)
}

func (r *positionStore) SetPosition(positionId uint64, position position.Position) error {
	r.data[position.StoreKeyPositions.String()].(*avl.Tree).Set(strconv.FormatUint(positionId, 10), position)
	return nil
}

func newMockPositionStore() position.IPositionStore {
	data := make(map[string]any)
	data[position.StoreKeyPositionNextID.String()] = uint64(1)
	data[position.StoreKeyPositions.String()] = avl.NewTree()

	return &positionStore{data: data}
}

func mockPositionV1(t *testing.T) *positionV1 {
	pool.InitPoolTest(t)
	gnft.InitGNFTTest(t)

	return &positionV1{store: newMockPositionStore()}
}
