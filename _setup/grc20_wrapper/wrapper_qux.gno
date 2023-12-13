package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/demo/qux"

	pRegistry "gno.land/r/demo/pool"
	rRegistry "gno.land/r/demo/router"
	sRegistry "gno.land/r/demo/staker"
)

type QuxTokenInterface struct{}

func (QuxTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return qux.Transfer
}

func (QuxTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return qux.TransferFrom
}

func (QuxTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return qux.BalanceOf
}

func (QuxTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return qux.Approve
}

var _ pRegistry.GRC20Interface = QuxTokenInterface{}
var _ rRegistry.GRC20Interface = QuxTokenInterface{}
var _ sRegistry.GRC20Interface = QuxTokenInterface{}
