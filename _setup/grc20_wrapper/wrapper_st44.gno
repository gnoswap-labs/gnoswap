package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st44"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest44TokenCTokenInterface struct{}

func (SwapTest44TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st44.Transfer
}

func (SwapTest44TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st44.TransferFrom
}

func (SwapTest44TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st44.BalanceOf
}

func (SwapTest44TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st44.Approve
}

var _ pRegistry.GRC20Interface = SwapTest44TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest44TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest44TokenCTokenInterface{}
