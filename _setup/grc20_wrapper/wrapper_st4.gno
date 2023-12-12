package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st4"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest4TokenCTokenInterface struct{}

func (SwapTest4TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st4.Transfer
}

func (SwapTest4TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st4.TransferFrom
}

func (SwapTest4TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st4.BalanceOf
}

func (SwapTest4TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st4.Approve
}

var _ pRegistry.GRC20Interface = SwapTest4TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest4TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest4TokenCTokenInterface{}
