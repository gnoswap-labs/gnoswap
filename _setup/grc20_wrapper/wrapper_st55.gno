package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st55"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest55TokenCTokenInterface struct{}

func (SwapTest55TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st55.Transfer
}

func (SwapTest55TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st55.TransferFrom
}

func (SwapTest55TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st55.BalanceOf
}

func (SwapTest55TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st55.Approve
}

var _ pRegistry.GRC20Interface = SwapTest55TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest55TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest55TokenCTokenInterface{}
