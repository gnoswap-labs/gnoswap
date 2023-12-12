package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st2"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest2TokenCTokenInterface struct{}

func (SwapTest2TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st2.Transfer
}

func (SwapTest2TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st2.TransferFrom
}

func (SwapTest2TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st2.BalanceOf
}

func (SwapTest2TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st2.Approve
}

var _ pRegistry.GRC20Interface = SwapTest2TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest2TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest2TokenCTokenInterface{}
