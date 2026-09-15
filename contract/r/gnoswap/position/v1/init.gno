package position

import (
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/position"
)

// init registers the version-one position implementation during realm initialization.
//
// Parameters:
//   - cur: runtime-supplied current realm context used to register this implementation
func init(cur realm) {
	registerPositionV1(cur)
}

// registerPositionV1 registers the version-one position implementation with the position realm.
//
// Parameters:
//   - cur: current realm context; this function crosses into the position realm to register the initializer
func registerPositionV1(cur realm) {
	position.RegisterInitializer(
		cross(cur),
		func(_ int, rlm realm, positionStore position.IPositionStore) position.IPosition {
			access.AssertIsRlmCurrent(0, rlm)

			err := initStoreData(0, rlm, positionStore)
			if err != nil {
				panic(err)
			}

			return NewPositionV1(positionStore, newGNFTAccessor())
		},
	)
}

// initStoreData creates the initial next-position-ID and positions-tree entries when absent.
//
// Parameters:
//   - _: leading integer discriminator; callers pass 0
//   - rlm: propagated realm context used for storage writes; the store validates it as current
//   - positionStore: position storage implementation to initialize
//
// Returns:
//   - err: nil when required store entries exist or are initialized; non-nil when a storage write fails
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
