package v4

import (
	"gno.land/r/gnoswap/pool"
)

type poolV1 struct {
	store pool.IPoolStore
}

func NewPoolV1(store pool.IPoolStore) pool.IPool {
	return &poolV1{
		store: store,
	}
}
