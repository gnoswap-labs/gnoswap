package v1

import (
	lo "gno.land/r/gnoswap/limit_order"
)

type limitOrderV1 struct {
	store        lo.ILimitOrderStore
	contractAddr address
}

func NewLimitOrderV1(loStore lo.ILimitOrderStore, contractAddr address) lo.ILimitOrder {
	return &limitOrderV1{
		store:        loStore,
		contractAddr: contractAddr,
	}
}
