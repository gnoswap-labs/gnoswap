package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/st11"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type SwapTest11TokenCTokenInterface struct{}

func (SwapTest11TokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return st11.Transfer
}

func (SwapTest11TokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return st11.TransferFrom
}

func (SwapTest11TokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return st11.BalanceOf
}

func (SwapTest11TokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return st11.Approve
}

var _ pRegistry.GRC20Interface = SwapTest11TokenCTokenInterface{}
var _ rRegistry.GRC20Interface = SwapTest11TokenCTokenInterface{}
var _ sRegistry.GRC20Interface = SwapTest11TokenCTokenInterface{}
