package grc20wrapper

import (
	"gno.land/r/demo/users"

	"gno.land/r/wugnot" // Wrapped (U)GNOT

	"gno.land/r/foo"

	"gno.land/r/bar"

	"gno.land/r/baz"

	"gno.land/r/qux"

	"gno.land/r/gns" // Staker Contract, Internal Reward
	"gno.land/r/obl" // Staker Contract, External Reward

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

type BarTokenInterface struct{}

func (BarTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return bar.Transfer
}

func (BarTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return bar.TransferFrom
}

func (BarTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return bar.BalanceOf
}

func (BarTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return bar.Approve
}

var _ pRegistry.GRC20Interface = BarTokenInterface{}
var _ rRegistry.GRC20Interface = BarTokenInterface{}

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

type OblTokenInterface struct{}

func (OblTokenInterface) Transfer() func(to users.AddressOrName, amount uint64) {
	return obl.Transfer
}

func (OblTokenInterface) TransferFrom() func(from, to users.AddressOrName, amount uint64) {
	return obl.TransferFrom
}

func (OblTokenInterface) BalanceOf() func(owner users.AddressOrName) uint64 {
	return obl.BalanceOf
}

func (OblTokenInterface) Approve() func(spender users.AddressOrName, amount uint64) {
	return obl.Approve
}

var _ pRegistry.GRC20Interface = OblTokenInterface{}
var _ rRegistry.GRC20Interface = OblTokenInterface{}
var _ sRegistry.GRC20Interface = OblTokenInterface{}

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

func init() {
	// pool register
	pRegistry.RegisterGRC20Interface("gno.land/r/wugnot", WugnotTokenInterface{})
	pRegistry.RegisterGRC20Interface("gno.land/r/foo", FooTokenInterface{})
	pRegistry.RegisterGRC20Interface("gno.land/r/bar", BarTokenInterface{})
	pRegistry.RegisterGRC20Interface("gno.land/r/baz", BazTokenInterface{})
	pRegistry.RegisterGRC20Interface("gno.land/r/qux", QuxTokenInterface{})
	pRegistry.RegisterGRC20Interface("gno.land/r/obl", OblTokenInterface{})
	pRegistry.RegisterGRC20Interface("gno.land/r/gns", GnsTokenInterface{})

	// router register
	rRegistry.RegisterGRC20Interface("gno.land/r/foo", FooTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/bar", BarTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/baz", BazTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/qux", QuxTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/obl", OblTokenInterface{})
	rRegistry.RegisterGRC20Interface("gno.land/r/gns", GnsTokenInterface{})

	// staker register
	// sRegistry.RegisterGRC20Interface("gno.land/r/wugnot", WugnotTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/obl", OblTokenInterface{})
	sRegistry.RegisterGRC20Interface("gno.land/r/gns", GnsTokenInterface{})
}
