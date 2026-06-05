package v1

import (
	"gno.land/r/gnoswap/position"
)

func init(cur realm) {
	registerPositionV1(cur)
}

func registerPositionV1(cur realm) {
	position.RegisterInitializer(
		cross(cur),
		func(_ int, rlm realm, positionStore position.IPositionStore) position.IPosition {
			if !rlm.IsCurrent() {
				panic(errSpoofedRealm)
			}

			err := initStoreData(0, rlm, positionStore)
			if err != nil {
				panic(err)
			}

			return NewPositionV1(positionStore, newGNFTAccessor())
		},
	)
}

func initStoreData(_ int, rlm realm, positionStore position.IPositionStore) error {
	if !positionStore.HasPositionNextIDStoreKey() {
		err := positionStore.SetPositionNextID(0, rlm, uint64(1))
		if err != nil {
			return err
		}
	}

	if !positionStore.HasPositionsStoreKey() {
		err := positionStore.SetPositions(0, rlm, position.NewPositionsTree())
		if err != nil {
			return err
		}
	}

	return nil
}
