package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st5"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest5TokenCTokenInterface struct{}

func (SwapTest5TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st5.Transfer
}

func (SwapTest5TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st5.TransferFrom
}

func (SwapTest5TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st5.BalanceOf
}

func (SwapTest5TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st5.Approve
}

var _ pRegistry.GRC20Interface = SwapTest5TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest5TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest5TokenCTokenInterface{}
