package register_gnodev

import (
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/foo20"
	"gno.land/r/demo/wugnot"

	pl "gno.land/r/demo/pool"
	rr "gno.land/r/demo/router"
	sr "gno.land/r/demo/staker"
)

type Foo20Token struct{}

func (Foo20Token) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return foo20.Transfer
}
func (Foo20Token) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return foo20.TransferFrom
}
func (Foo20Token) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return foo20.BalanceOf
}
func (Foo20Token) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return foo20.Approve
}

type WugnotToken struct{}

func (WugnotToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return wugnot.Transfer
}
func (WugnotToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return wugnot.TransferFrom
}
func (WugnotToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return wugnot.BalanceOf
}
func (WugnotToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return wugnot.Approve
}

func init() {
	pl.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})

	sr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	sr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})

	rr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
}
