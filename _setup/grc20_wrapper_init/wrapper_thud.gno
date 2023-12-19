package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/thud"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type ThudTokenInterface struct{}

func (ThudTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return thud.Transfer
}

func (ThudTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return thud.TransferFrom
}

func (ThudTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return thud.BalanceOf
}

func (ThudTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return thud.Approve
}

var _ pRegistry.GRC20Interface = ThudTokenInterface{}
var _ rRegistry.GRC20Interface = ThudTokenInterface{}
var _ sRegistry.GRC20Interface = ThudTokenInterface{}
