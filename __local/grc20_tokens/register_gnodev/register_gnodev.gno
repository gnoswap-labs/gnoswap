package register_gnodev

import (
	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/foo20"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"
	"gno.land/r/demo/usdc"
	"gno.land/r/demo/wugnot"

	pl "gno.land/r/demo/pool"
	rr "gno.land/r/demo/router"
	sr "gno.land/r/demo/staker"
)

type FooToken struct{}

func (FooToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return foo.Transfer
}
func (FooToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return foo.TransferFrom
}
func (FooToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return foo.BalanceOf
}
func (FooToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return foo.Approve
}

type BarToken struct{}

func (BarToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return bar.Transfer
}
func (BarToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return bar.TransferFrom
}
func (BarToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return bar.BalanceOf
}
func (BarToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return bar.Approve
}

type BazToken struct{}

func (BazToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return baz.Transfer
}
func (BazToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return baz.TransferFrom
}
func (BazToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return baz.BalanceOf
}
func (BazToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return baz.Approve
}

type QuxToken struct{}

func (QuxToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return qux.Transfer
}
func (QuxToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return qux.TransferFrom
}
func (QuxToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return qux.BalanceOf
}
func (QuxToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return qux.Approve
}

type GnsToken struct{}

func (GnsToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return gns.Transfer
}
func (GnsToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return gns.TransferFrom
}
func (GnsToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return gns.BalanceOf
}
func (GnsToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return gns.Approve
}

type OblToken struct{}

func (OblToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return obl.Transfer
}
func (OblToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return obl.TransferFrom
}
func (OblToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return obl.BalanceOf
}
func (OblToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return obl.Approve
}

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

type UsdcToken struct{}

func (UsdcToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return usdc.Transfer
}
func (UsdcToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return usdc.TransferFrom
}
func (UsdcToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return usdc.BalanceOf
}
func (UsdcToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return usdc.Approve
}

func init() {
	pl.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/gns", GnsToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/obl", OblToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/usdc", UsdcToken{})

	sr.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/gns", GnsToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/obl", OblToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	sr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	sr.RegisterGRC20Interface("gno.land/r/demo/usdc", UsdcToken{})

	rr.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/gns", GnsToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/obl", OblToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/foo20", Foo20Token{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/usdc", UsdcToken{})
}
