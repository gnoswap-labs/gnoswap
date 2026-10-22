package dca_order

import (
	dca "gno.land/r/gnoswap/test/dca_order"
)

type dcaOrderV1 struct {
	store dca.IDCAOrderStore
}

// NewDCAOrderV1 creates the v1 implementation over the shared store.
func NewDCAOrderV1(dcaStore dca.IDCAOrderStore) dca.IDCAOrder {
	return &dcaOrderV1{store: dcaStore}
}
