package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/baz"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type BazTokenInterface struct{}

func (BazTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return baz.Transfer
}

func (BazTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return baz.TransferFrom
}

func (BazTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return baz.BalanceOf
}

func (BazTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return baz.Approve
}

var _ pRegistry.GRC20Interface = BazTokenInterface{}
var _ rRegistry.GRC20Interface = BazTokenInterface{}
var _ sRegistry.GRC20Interface = BazTokenInterface{}
