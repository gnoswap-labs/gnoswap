package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/st3"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type SwapTest3TokenCTokenInterface struct{}

func (SwapTest3TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st3.Transfer
}

func (SwapTest3TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st3.TransferFrom
}

func (SwapTest3TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st3.BalanceOf
}

func (SwapTest3TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st3.Approve
}

var _ pRegistry.GRC20Interface = SwapTest3TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest3TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest3TokenCTokenInterface{}
