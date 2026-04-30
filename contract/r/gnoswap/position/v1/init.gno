package v1

import (
	bptree "gno.land/p/nt/bptree/v0"
	"gno.land/r/gnoswap/position"
)

func init() {
	registerPositionV1()
}

func registerPositionV1() {
	position.RegisterInitializer(cross, func(positionStore position.IPositionStore) position.IPosition {
		err := initStoreData(positionStore)
		if err != nil {
			panic(err)
		}

		return NewPositionV1(positionStore, newGNFTAccessor())
	})
}

func initStoreData(positionStore position.IPositionStore) error {
	if !positionStore.HasPositionNextIDStoreKey() {
		err := positionStore.SetPositionNextID(uint64(1))
		if err != nil {
			return err
		}
	}

	if !positionStore.HasPositionsStoreKey() {
		err := positionStore.SetPositions(bptree.NewBPTreeN(16))
		if err != nil {
			return err
		}
	}

	return nil
}
