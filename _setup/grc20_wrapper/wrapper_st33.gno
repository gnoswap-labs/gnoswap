package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st33"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest33TokenCTokenInterface struct{}

func (SwapTest33TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st33.Transfer
}

func (SwapTest33TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st33.TransferFrom
}

func (SwapTest33TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st33.BalanceOf
}

func (SwapTest33TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st33.Approve
}

var _ pRegistry.GRC20Interface = SwapTest33TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest33TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest33TokenCTokenInterface{}
