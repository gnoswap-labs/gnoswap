package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/wugnot"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type WugnotTokenInterface struct{}

func (WugnotTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return wugnot.Transfer
}

func (WugnotTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return wugnot.TransferFrom
}

func (WugnotTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return wugnot.BalanceOf
}

func (WugnotTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return wugnot.Approve
}

var _ pRegistry.GRC20Interface = WugnotTokenInterface{}
var _ rRegistry.GRC20Interface = WugnotTokenInterface{}
var _ sRegistry.GRC20Interface = WugnotTokenInterface{}
