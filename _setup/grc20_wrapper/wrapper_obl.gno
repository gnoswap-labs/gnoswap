package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/obl"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type OblTokenInterface struct{}

func (OblTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return obl.Transfer
}

func (OblTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return obl.TransferFrom
}

func (OblTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return obl.BalanceOf
}

func (OblTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return obl.Approve
}

var _ pRegistry.GRC20Interface = OblTokenInterface{}
var _ rRegistry.GRC20Interface = OblTokenInterface{}
var _ sRegistry.GRC20Interface = OblTokenInterface{}
