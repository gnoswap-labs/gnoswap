package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/foo"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type FooTokenInterface struct{}

func (FooTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return foo.Transfer
}

func (FooTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return foo.TransferFrom
}

func (FooTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return foo.BalanceOf
}

func (FooTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return foo.Approve
}

var _ pRegistry.GRC20Interface = FooTokenInterface{}
var _ rRegistry.GRC20Interface = FooTokenInterface{}
var _ sRegistry.GRC20Interface = FooTokenInterface{}
