package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st1"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest1TokenCTokenInterface struct{}

func (SwapTest1TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st1.Transfer
}

func (SwapTest1TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st1.TransferFrom
}

func (SwapTest1TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st1.BalanceOf
}

func (SwapTest1TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st1.Approve
}

var _ pRegistry.GRC20Interface = SwapTest1TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest1TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest1TokenCTokenInterface{}
