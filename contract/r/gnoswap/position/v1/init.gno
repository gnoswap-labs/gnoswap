package v1

import (
	"gno.land/p/nt/avl"
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
		err := positionStore.SetPositions(avl.NewTree())
		if err != nil {
			return err
		}
	}

	return nil
}
