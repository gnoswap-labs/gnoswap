package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/testtokenb"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type TestTokenBTokenInterface struct{}

func (TestTokenBTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return testtokenb.Transfer
}

func (TestTokenBTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return testtokenb.TransferFrom
}

func (TestTokenBTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return testtokenb.BalanceOf
}

func (TestTokenBTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return testtokenb.Approve
}

var _ pRegistry.GRC20Interface = TestTokenBTokenInterface{}
var _ rRegistry.GRC20Interface = TestTokenBTokenInterface{}
var _ sRegistry.GRC20Interface = TestTokenBTokenInterface{}
