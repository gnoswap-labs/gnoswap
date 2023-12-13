package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/testtokena"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type TestTokenATokenInterface struct{}

func (TestTokenATokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return testtokena.Transfer
}

func (TestTokenATokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return testtokena.TransferFrom
}

func (TestTokenATokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return testtokena.BalanceOf
}

func (TestTokenATokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return testtokena.Approve
}

var _ pRegistry.GRC20Interface = TestTokenATokenInterface{}
var _ rRegistry.GRC20Interface = TestTokenATokenInterface{}
var _ sRegistry.GRC20Interface = TestTokenATokenInterface{}
