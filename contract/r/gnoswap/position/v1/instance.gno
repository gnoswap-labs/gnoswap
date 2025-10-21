package v1

import "gno.land/r/gnoswap/position"

type positionV1 struct {
	store position.IPositionStore
}

func NewPositionV1(positionStore position.IPositionStore) position.IPosition {
	return &positionV1{
		store: positionStore,
	}
}
