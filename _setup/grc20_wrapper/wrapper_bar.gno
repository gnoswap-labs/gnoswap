package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/bar"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type BarTokenInterface struct{}

func (BarTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return bar.Transfer
}

func (BarTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return bar.TransferFrom
}

func (BarTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return bar.BalanceOf
}

func (BarTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return bar.Approve
}

var _ pRegistry.GRC20Interface = BarTokenInterface{}
var _ rRegistry.GRC20Interface = BarTokenInterface{}
var _ sRegistry.GRC20Interface = BarTokenInterface{}
