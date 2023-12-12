package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/gns"

	pRegistry "gno.land/r/pool"
	rRegistry "gno.land/r/router"
	sRegistry "gno.land/r/staker"
)

type GnsTokenInterface struct{}

func (GnsTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return gns.Transfer
}

func (GnsTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return gns.TransferFrom
}

func (GnsTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return gns.BalanceOf
}

func (GnsTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return gns.Approve
}

var _ pRegistry.GRC20Interface = GnsTokenInterface{}
var _ rRegistry.GRC20Interface = GnsTokenInterface{}
var _ sRegistry.GRC20Interface = GnsTokenInterface{}
