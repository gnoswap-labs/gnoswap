package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/testtokenc"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type TestTokenCTokenInterface struct{}

func (TestTokenCTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return testtokenc.Transfer
}

func (TestTokenCTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return testtokenc.TransferFrom
}

func (TestTokenCTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return testtokenc.BalanceOf
}

func (TestTokenCTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return testtokenc.Approve
}

var _ pRegistry.GRC20Interface = TestTokenCTokenInterface{}
var _ rRegistry.GRC20Interface = TestTokenCTokenInterface{}
var _ sRegistry.GRC20Interface = TestTokenCTokenInterface{}
