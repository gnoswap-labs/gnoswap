package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st22"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest22TokenCTokenInterface struct{}

func (SwapTest22TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st22.Transfer
}

func (SwapTest22TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st22.TransferFrom
}

func (SwapTest22TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st22.BalanceOf
}

func (SwapTest22TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st22.Approve
}

var _ pRegistry.GRC20Interface = SwapTest22TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest22TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest22TokenCTokenInterface{}
