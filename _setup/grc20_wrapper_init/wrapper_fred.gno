package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/fred"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type FredTokenInterface struct{}

func (FredTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return fred.Transfer
}

func (FredTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return fred.TransferFrom
}

func (FredTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return fred.BalanceOf
}

func (FredTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return fred.Approve
}

var _ pRegistry.GRC20Interface = FredTokenInterface{}
var _ rRegistry.GRC20Interface = FredTokenInterface{}
var _ sRegistry.GRC20Interface = FredTokenInterface{}
